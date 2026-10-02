#requires -Version 7.0

<#
.SYNOPSIS
    Shows keyword and semantic detections for each sample log line in one table.

.DESCRIPTION
    Sends each line to Jev and checks the same line against a literal regex.
    A check mark means the filter flagged the line as a storage issue; an x
    means it did not. These marks show filter output, not whether it was right.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Compare-LogFilters-Table.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) {
    throw 'Set TYPESAFE_API_KEY before running this live Jev demo.'
}

Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

$rawLog = @"
2026-09-27 06:01:12 INFO  Service started on port 8080
2026-09-27 06:02:45 INFO  Nightly disk check passed
2026-09-27 06:03:10 WARN  Volume /var at 98% capacity
2026-09-27 06:04:22 ERROR write failed: ENOSPC
2026-09-27 06:05:01 INFO  User jsmith logged in
2026-09-27 06:05:33 ERROR No space left on device
2026-09-27 06:06:14 WARN  Temp directory quota policy updated
2026-09-27 06:07:48 ERROR Cannot extend tablespace USERS: out of storage
2026-09-27 06:08:02 INFO  Cache cleared, 0 items removed
2026-09-27 06:09:19 WARN  Backup job skipped: target drive full
2026-09-27 06:10:05 ERROR Connection to db01 timed out
2026-09-27 06:11:30 INFO  Disk space report emailed to ops
"@

$logLines = @($rawLog -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$pattern = 'disk|space|quota'

$question = New-JevQuestion -Name diskIssue -Type Noul `
    -Instructions 'Does this log entry indicate that a storage volume, filesystem, or database tablespace is full or close to full, causing writes or backups to fail?' `
    -Criteria @{
    true  = 'Storage capacity is exhausted or nearly exhausted and is causing, or is likely to cause, failed writes or backups.'
    false = 'The entry only mentions disks, space, or quotas without indicating a storage capacity problem.'
}

Write-Host "Checking $($logLines.Count) log lines with Jev (one live request per line) and -match..." -ForegroundColor Cyan
Write-Host "Semantic threshold: 0.8. A check mark means the filter flagged the line; an x means it did not." -ForegroundColor DarkGray

$results = for ($index = 0; $index -lt $logLines.Count; $index++) {
    $decision = $logLines[$index] | Invoke-Jev -Question $question
    #$probability = [double] $decision.diskIssue

    [pscustomobject]@{
        Line        = $index + 1
        State       = $logLines[$index]
        SemanticHit = ($decision.diskIssue -ge 0.8)
        RegexHit    = ($logLines[$index] -match $pattern)
    }
}

$longestState = ($results | ForEach-Object { $_.State.Length } | Measure-Object -Maximum).Maximum
$stateWidth = [math]::Max(48, [math]::Min(88, $longestState))
$rowFormat = "{0,-$stateWidth} {1,-8} {2,-8}"

function Write-ComparisonGroup {
    param(
        [Parameter(Mandatory)]
        [string] $Title,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Rows,

        [Parameter(Mandatory)]
        [int] $StateWidth
    )

    Write-Host "`n$Title ($($Rows.Count))" -ForegroundColor Green
    Write-Host ($rowFormat -f 'State', 'Semantic', 'Regex') -ForegroundColor Cyan
    Write-Host ('-' * ($StateWidth + 19)) -ForegroundColor DarkGray

    if ($Rows.Count -eq 0) {
        Write-Host '(none)' -ForegroundColor DarkGray
        return
    }

    foreach ($row in ($Rows | Sort-Object Line)) {
        $state = [string] $row.State
        $firstLine = $state.Substring(0, [math]::Min($state.Length, $StateWidth))
        Write-Host ($firstLine.PadRight($StateWidth) + ' ') -NoNewline

        $semanticMark = if ($row.SemanticHit) { '✓' } else { '✗' }
        $semanticColor = if ($row.SemanticHit) { 'Green' } else { 'Red' }
        Write-Host ($semanticMark.PadRight(8) + ' ') -ForegroundColor $semanticColor -NoNewline

        $regexMark = if ($row.RegexHit) { '✓' } else { '✗' }
        $regexColor = if ($row.RegexHit) { 'Green' } else { 'Red' }
        Write-Host $regexMark -ForegroundColor $regexColor

        for ($offset = $StateWidth; $offset -lt $state.Length; $offset += $StateWidth) {
            $segmentLength = [math]::Min($StateWidth, $state.Length - $offset)
            Write-Host ('  ' + $state.Substring($offset, $segmentLength))
        }
    }
}

$bothFound = @($results | Where-Object { $_.SemanticHit -and $_.RegexHit })
$semanticOnly = @($results | Where-Object { $_.SemanticHit -and -not $_.RegexHit })
$regexOnly = @($results | Where-Object { $_.RegexHit -and -not $_.SemanticHit })
$neitherFound = @($results | Where-Object { -not $_.SemanticHit -and -not $_.RegexHit })

Write-ComparisonGroup -Title 'Both filters flagged the line' -Rows $bothFound -StateWidth $stateWidth
Write-ComparisonGroup -Title 'Semantic only — Jev flagged it' -Rows $semanticOnly -StateWidth $stateWidth
Write-ComparisonGroup -Title 'Regex only — keyword match flagged it' -Rows $regexOnly -StateWidth $stateWidth
Write-ComparisonGroup -Title 'Neither filter flagged the line' -Rows $neitherFound -StateWidth $stateWidth

Write-Host 'Expected issues: 98% volume, ENOSPC, no-space error, tablespace failure, and full backup target.' -ForegroundColor DarkGray
Write-Host 'A red x on one of those is a miss; a green check on a harmless line is a false positive.' -ForegroundColor DarkGray
