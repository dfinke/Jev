param(
    [string] $RunDirectory = (Join-Path $env:TEMP 'Jev-Live-Routing'),

    [ValidateRange(1, 32)]
    [int] $ThrottleLimit = 4,

    [string] $StatusPath
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Watch-Routing.ps1 requires PowerShell 7 or later for parallel processing.'
}

$jevModulePath = (Get-Module -Name Jev | Select-Object -First 1).Path
if (-not $jevModulePath) {
    throw 'Import the Jev module in this console before starting Watch-Routing.ps1.'
}

$categories = @('billing', 'account', 'bug', 'feature_request', 'how_to', 'other')
$question = New-JevQuestion -Name category -Type Choice `
    -Instructions 'Which support queue should own this customer message?' `
    -Criteria ([ordered]@{
        billing         = 'A question or problem about charges, invoices, subscriptions, payments, or refunds.'
        account         = 'A problem signing in, resetting a password, authenticating, or accessing an account.'
        bug             = 'An existing product feature is failing, returning an error, or behaving incorrectly.'
        feature_request = 'The customer wants a new product capability or an enhancement to an existing feature.'
        how_to          = 'The customer asks how to use or find an existing product feature.'
        other           = 'General feedback, thanks, unrelated messages, or anything that does not fit the other queues.'
    })
$runDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$queueDirectory = Join-Path $runDirectory 'Queues'
$messagePath = Join-Path $runDirectory 'messages.jsonl'
$failurePath = Join-Path $queueDirectory '_failed.jsonl'
if ([string]::IsNullOrWhiteSpace($StatusPath)) {
    $StatusPath = Join-Path $runDirectory 'status.json'
}
$StatusPath = [System.IO.Path]::GetFullPath($StatusPath)
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
$counts = [ordered]@{}
foreach ($category in $categories) { $counts[$category] = 0 }
$counts['failed'] = 0
$totalProcessed = 0
$script:latest = 'Waiting for the first decision...'
$script:latestCategory = ''
$script:latestMessage = 'Waiting for the first decision...'
$script:latestError = ''

if (-not (Test-Path -LiteralPath $messagePath)) {
    throw "Message stream not found at '$messagePath'. Start Generate-Messages.ps1 first."
}

New-Item -ItemType Directory -Path $queueDirectory -Force | Out-Null

function Add-JsonLine {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [object] $Value
    )

    $json = ConvertTo-Json -InputObject $Value -Compress -Depth 8
    [System.IO.File]::AppendAllText($Path, $json + [Environment]::NewLine, $utf8WithoutBom)
}

function Show-RoutingDashboard {
    Clear-Host
    Write-Host 'JEV LIVE MESSAGE ROUTER' -ForegroundColor Cyan
    Write-Host ('Processed: {0}    Failed: {1}    Parallel requests: {2}' -f $totalProcessed, $counts['failed'], $ThrottleLimit) -ForegroundColor White
    Write-Host ''
    Write-Host ('{0,-22}{1,8}' -f 'QUEUE', 'COUNT') -ForegroundColor DarkCyan
    Write-Host ('{0,-22}{1,8}' -f '-----', '-----') -ForegroundColor DarkCyan

    foreach ($category in $categories) {
        Write-Host ('{0,-22}{1,8}' -f $category, $counts[$category])
    }

    Write-Host ''
    $oneLineLatest = ($script:latest -replace '\s+', ' ').Trim()
    if ($oneLineLatest.Length -gt 105) { $oneLineLatest = $oneLineLatest.Substring(0, 102) + '...' }
    Write-Host "Latest: $oneLineLatest" -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Queue files: '
    Write-Host $queueDirectory -ForegroundColor DarkGray
    Write-Host "Stream: $messagePath" -ForegroundColor DarkGray
    Write-Host 'Press Ctrl+C to stop watching.' -ForegroundColor DarkGray
}

function Write-StatusSnapshot {
    $snapshot = [ordered]@{
        updatedUtc      = [DateTimeOffset]::UtcNow.ToString('O')
        totalProcessed  = $script:totalProcessed
        failed          = $counts['failed']
        counts          = $counts
        latestCategory  = $script:latestCategory
        latestMessage   = $script:latestMessage
        latestError     = $script:latestError
    }

    try {
        $json = ConvertTo-Json -InputObject $snapshot -Compress -Depth 5
        [System.IO.File]::WriteAllText($StatusPath, $json, $utf8WithoutBom)
    }
    catch {
        Write-Warning "Could not update watcher status file '$StatusPath': $($_.Exception.Message)"
    }
}

function Write-FailedMessage {
    param(
        [string] $Id,
        [string] $Message,
        [string] $ErrorMessage
    )

    $failure = [ordered]@{
        id          = $Id
        routedUtc   = [DateTimeOffset]::UtcNow.ToString('O')
        message     = $Message
        error       = $ErrorMessage
    }
    Add-JsonLine -Path $failurePath -Value $failure
    $counts['failed']++
    $script:latest = "NOT ROUTED [$Id] $Message — $ErrorMessage"
    $script:latestCategory = 'failed'
    $script:latestMessage = $Message
    $script:latestError = $ErrorMessage
    Write-StatusSnapshot
    Show-RoutingDashboard
}

Show-RoutingDashboard
Write-StatusSnapshot

# Jev requests run concurrently. Results return here to one coordinator, which
# keeps queue-file writes, counters, and dashboard updates safe and consistent.
Get-Content -LiteralPath $messagePath -Encoding UTF8 -Wait |
    ForEach-Object -Parallel {
        $line = [string] $_
        if ([string]::IsNullOrWhiteSpace($line)) { return }

        try {
            if (-not (Get-Command Invoke-Jev -ErrorAction SilentlyContinue)) {
                Import-Module -Name $using:jevModulePath -ErrorAction Stop
            }

            $record = ConvertFrom-Json -InputObject $line -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace([string] $record.id) -or [string]::IsNullOrWhiteSpace([string] $record.message)) {
                throw 'The event must contain non-empty id and message fields.'
            }

            # Jev sees only the message. Criteria describe each allowed queue.
            $decision = Invoke-Jev -State ([string] $record.message) -Question $using:question -ErrorAction Stop
            $category = [string] $decision.category
            if ($category -notin $using:categories) {
                throw "Jev returned an unexpected category '$category'."
            }

            [pscustomobject]@{
                Success   = $true
                Id        = [string] $record.id
                CreatedUtc = [string] $record.createdUtc
                Message   = [string] $record.message
                Category  = $category
                Error     = $null
            }
        }
        catch {
            $id = if ($record -and $record.id) { [string] $record.id } else { 'unknown' }
            $message = if ($record -and $record.message) { [string] $record.message } else { $line }
            [pscustomobject]@{
                Success   = $false
                Id        = $id
                CreatedUtc = if ($record) { [string] $record.createdUtc } else { '' }
                Message   = $message
                Category  = $null
                Error     = $_.Exception.Message
            }
        }
    } -ThrottleLimit $ThrottleLimit |
    ForEach-Object {
        $result = $_
        $script:totalProcessed++

        if (-not $result.Success) {
            Write-FailedMessage -Id $result.Id -Message $result.Message -ErrorMessage $result.Error
            return
        }

        $queueRecord = [ordered]@{
            id         = $result.Id
            createdUtc = $result.CreatedUtc
            routedUtc  = [DateTimeOffset]::UtcNow.ToString('O')
            category   = $result.Category
            message    = $result.Message
        }
        $queuePath = Join-Path $queueDirectory "$($result.Category).jsonl"
        Add-JsonLine -Path $queuePath -Value $queueRecord
        $counts[$result.Category]++
        $script:latest = "[$($result.Category)] $($result.Message)"
        $script:latestCategory = $result.Category
        $script:latestMessage = $result.Message
        $script:latestError = ''
        Write-StatusSnapshot
        Show-RoutingDashboard
    }
