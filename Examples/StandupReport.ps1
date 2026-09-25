#requires -Version 7.0

[CmdletBinding()]
param(
    [string] $RepositoryPath = (Get-Location).Path,

    [ValidateRange(1, 30)]
    [int] $Days = 1,

    [ValidateRange(1, 100)]
    [int] $CommitLimit = 30,

    [string[]] $Today = @(),

    [string[]] $Blockers = @()
)

# Set TYPESAFE_API_KEY before running this example.

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$commitLines = @(git -C $RepositoryPath log -n $CommitLimit "--since=$Days days ago" '--format=%h%x09%s')
if ($LASTEXITCODE -ne 0) {
    throw "Could not read Git history from '$RepositoryPath'. Check the path and confirm it is a Git repository."
}

$commits = foreach ($line in $commitLines) {
    $parts = $line -split "`t", 2
    if ($parts.Count -eq 2) {
        [pscustomobject]@{
            Commit  = $parts[0]
            Subject = $parts[1]
        }
    }
}

$workingTree = @(git -C $RepositoryPath status --short)
if ($LASTEXITCODE -ne 0) {
    throw "Could not read working-tree status from '$RepositoryPath'."
}

$question = New-JevQuestion `
    -Name updateType `
    -Type Choice `
    -Instructions 'Classify the outcome described by this Git commit subject for a team standup. Choose delivery for a user-visible feature or behavior change, reliability for a bug fix or quality improvement, exploration for investigation or a prototype, and internal for documentation, tests, refactoring, or build maintenance.' `
    -Criteria ([ordered]@{
        delivery    = 'A user-visible feature or behavior change.'
        reliability = 'A bug fix or quality improvement.'
        exploration = 'An investigation, experiment, or prototype.'
        internal    = 'Documentation, tests, refactoring, or build maintenance.'
    })

$updates = foreach ($commit in $commits) {
    $decision = Invoke-Jev -State $commit -Question $question
    $answer = $decision.answers.updateType

    [pscustomobject]@{
        Type       = $decision.updateType
        Confidence = [math]::Round([double]$answer.confidence, 2)
        Commit     = $decision.Commit
        Subject    = $decision.Subject
    }
}

Write-Host "YESTERDAY (last $Days day(s))" -ForegroundColor Cyan
if (@($updates).Count -eq 0) {
    Write-Host 'No commits found in this period.'
}
else {
    foreach ($type in 'delivery', 'reliability', 'exploration', 'internal') {
        $items = @($updates | Where-Object Type -eq $type)
        if ($items.Count -eq 0) { continue }

        Write-Host "`n$($type.ToUpperInvariant())"
        $items | Sort-Object Confidence -Descending | Format-Table Confidence, Commit, Subject -Wrap
    }
}

Write-Host "`nWORKING TREE (possible work in progress)" -ForegroundColor Cyan
if ($workingTree.Count -eq 0) {
    Write-Host 'Clean.'
}
else {
    $workingTree
}

Write-Host "`nTODAY (supplied by you)" -ForegroundColor Cyan
if ($Today.Count -eq 0) { Write-Host 'No plan supplied.' } else { $Today | ForEach-Object { "- $_" } }

Write-Host "`nBLOCKERS (supplied by you)" -ForegroundColor Cyan
if ($Blockers.Count -eq 0) { Write-Host 'None supplied.' } else { $Blockers | ForEach-Object { "- $_" } }
