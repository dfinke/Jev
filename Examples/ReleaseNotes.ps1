#requires -Version 7.0

[CmdletBinding()]
param(
    [string] $RepositoryPath = (Get-Location).Path,

    [ValidateRange(1, 100)]
    [int] $Count = 20
)

# Set TYPESAFE_API_KEY before running this example.

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$commitLines = @(git -C $RepositoryPath log -n $Count --format='%h%x09%s')
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

$question = New-JevQuestion `
    -Name category `
    -Type Choice `
    -Instructions 'Classify this Git commit using only its subject. Choose breaking for an incompatible public change that likely requires users to change scripts or configuration; feature for a user-visible capability; fix for a user-visible defect correction; internal for tests, documentation, refactoring, or maintenance without a user-visible behavior change.' `
    -Criteria ([ordered]@{
        breaking = 'An incompatible public change that may require existing users to update scripts or configuration.'
        feature  = 'A new user-visible capability or meaningful improvement.'
        fix      = 'A correction to a user-visible defect.'
        internal = 'Tests, documentation, refactoring, or maintenance without a user-visible behavior change.'
    })

$results = foreach ($commit in $commits) {
    $decision = Invoke-Jev -State $commit -Question $question
    $answer = $decision.answers.category

    [pscustomobject]@{
        Category   = $decision.category
        Confidence = [math]::Round([double]$answer.confidence, 2)
        Commit     = $decision.Commit
        Subject    = $decision.Subject
    }
}

foreach ($category in 'breaking', 'feature', 'fix', 'internal') {
    $items = @($results | Where-Object Category -eq $category)
    if ($items.Count -eq 0) { continue }

    $heading = if ($category -eq 'internal') { 'Internal changes (left out of the draft)' } else { $category.ToUpperInvariant() }
    Write-Host "`n$heading" -ForegroundColor Cyan
    $items | Sort-Object Confidence -Descending | Format-Table Confidence, Commit, Subject -Wrap
}

Write-Host "`nDraft release notes (review before publishing):" -ForegroundColor Cyan
$results |
    Where-Object Category -in @('breaking', 'feature', 'fix') |
    Sort-Object @{ Expression = { @('breaking', 'feature', 'fix').IndexOf($_.Category) } }, @{ Expression = 'Confidence'; Descending = $true } |
    ForEach-Object { "- [$($_.Category)] $($_.Subject)" }
