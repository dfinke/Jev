#requires -Version 7.0

<#
.SYNOPSIS
    Ranks startup log entries by how strongly they explain an application failure.

.DESCRIPTION
    Sends the complete log and one Score question per log entry in a single
    Invoke-Jev call. Jev scores each candidate against the same root-cause
    question; PowerShell then sorts the returned scores from strongest to weakest.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Rank-StartupLogCandidates.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) {
    throw 'Set TYPESAFE_API_KEY before running this live Jev example.'
}

Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

$logPath = Join-Path $PSScriptRoot 'app.log'
$scoreCriteria = @(
    'Unrelated or routine information; it does not explain the startup failure.'
    'Related context, a symptom, or a downstream result, but not the initiating cause.'
    'Direct evidence of the condition that caused the startup failure.'
)

# Read the log once. As each line arrives, keep it as a candidate, add it to
# the shared incident context, and create the matching bounded Jev question.
$candidates = [System.Collections.Generic.List[object]]::new()
$questions = [System.Collections.Generic.List[object]]::new()
$logEntries = [System.Collections.Generic.List[string]]::new()
$index = 0

foreach ($line in Get-Content -LiteralPath $logPath) {
    $index++
    $candidateId = 'L{0:D2}' -f $index
    $questionName = 'line{0:D2}' -f $index

    $candidates.Add([pscustomobject]@{
        Id           = $candidateId
        QuestionName = $questionName
        Log          = $line
    })
    $logEntries.Add("[$candidateId] $line")
    $questions.Add((New-JevQuestion -Name $questionName -Type Score `
        -Instructions "Given the complete incident log, how strongly does candidate [$candidateId] explain why invoice-api failed to start?" `
        -Criteria $scoreCriteria))
}

if ($candidates.Count -eq 0) {
    throw "No log entries found in '$logPath'."
}

$incidentState = [pscustomobject]@{
    Goal        = 'Identify which individual log entry best explains why invoice-api failed to start.'
    Application = 'invoice-api'
    LogEntries  = $logEntries.ToArray()
}

# One request contains all candidate questions. There is no separate model call per line.
$decision = Invoke-Jev -State $incidentState -Question $questions.ToArray()

$ranked = foreach ($candidate in $candidates) {
    $score = [double] $decision.($candidate.QuestionName)
    $confidence = [double] $decision.answers.($candidate.QuestionName).confidence

    [pscustomobject]@{
        Rank       = 0
        Candidate  = $candidate.Id
        Score      = $score
        Confidence = [math]::Round($confidence, 3)
        LogEntry   = $candidate.Log
    }
}

$rank = 0
$ranked | Sort-Object Score, Confidence -Descending | ForEach-Object {
    $rank++
    $_.Rank = $rank
    $_
} | Format-Table Rank, Candidate, Score, Confidence, LogEntry -AutoSize -Wrap

Write-Host ''
Write-Host 'Score is a position on a 0-to-2 relevance/evidence scale; it can be fractional.'
Write-Host 'Confidence is Jev confidence in that score and is used only to break score ties.'
Write-Host 'The top entry is a lead for an engineer to verify, not proof of root cause.'
