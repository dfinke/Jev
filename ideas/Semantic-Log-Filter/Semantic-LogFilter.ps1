#requires -Version 7.0

<#
.SYNOPSIS
    Evaluates sample log lines for storage capacity problems with Jev.

.DESCRIPTION
    Sends each log line to Jev with one bounded Noul question, then displays
    the returned probability alongside the hand-labeled sample expectation.
    The script reports results only; it does not take operational action.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Semantic-LogFilter.ps1
#>
[CmdletBinding()]
param(
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) {
    throw 'Set TYPESAFE_API_KEY before running this live Jev demo.'
}

Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

$logPath = Join-Path $PSScriptRoot 'app.log'
$expectedPath = Join-Path $PSScriptRoot 'expected.csv'
$logLines = @(Get-Content -LiteralPath $logPath)
$expectedRows = @(Import-Csv -LiteralPath $expectedPath)

if ($logLines.Count -ne $expectedRows.Count) {
    throw "app.log has $($logLines.Count) lines, but expected.csv has $($expectedRows.Count) rows. Keep them aligned."
}

$question = New-JevQuestion -Name diskIssue -Type Noul `
    -Instructions 'Does this log entry indicate that a storage volume, filesystem, or database tablespace is full or close to full, causing writes or backups to fail?' `
    -Criteria @{
        true  = 'Storage capacity is exhausted or nearly exhausted and is causing, or is likely to cause, failed writes or backups.'
        false = 'The entry only mentions disks, space, or quotas without indicating a storage capacity problem.'
    }

if (-not $PassThru) {
    Write-Host "Evaluating $($logLines.Count) log lines with Jev (one live request per line)." -ForegroundColor Cyan
    Write-Host 'Each line is being classified; this script does not automate remediation.' -ForegroundColor DarkGray
}

$results = for ($index = 0; $index -lt $logLines.Count; $index++) {
    if ([int] $expectedRows[$index].Line -ne ($index + 1)) {
        throw "expected.csv rows must be ordered by line number. Check row $($index + 1)."
    }

    $decision = $logLines[$index] | Invoke-Jev -Question $question
    $probability = [double] $decision.diskIssue

    # These cutoffs are example PowerShell policy, not Jev defaults.
    $label = if ($probability -ge 0.8) {
        'Storage issue'
    }
    elseif ($probability -le 0.2) {
        'No storage issue'
    }
    else {
        'Review'
    }

    [pscustomobject]@{
        Line                 = $index + 1
        ExpectedStorageIssue = [bool]::Parse($expectedRows[$index].ExpectedStorageIssue)
        JevProbability       = [math]::Round($probability, 2)
        JevResult            = $label
        LogEntry             = $logLines[$index]
    }
}

if ($PassThru) {
    $results
}
else {
    $results | Format-Table Line, ExpectedStorageIssue, JevProbability, JevResult, LogEntry -Wrap -AutoSize
}
