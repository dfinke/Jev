#requires -Version 7.0

<#
.SYNOPSIS
    Filters the sample log with a fixed keyword pattern.

.DESCRIPTION
    Shows what a deterministic -match filter catches and misses against the
    hand-labeled sample fixture. This script does not call Jev.

.EXAMPLE
    ./Regex-LogFilter.ps1
#>
[CmdletBinding()]
param(
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'

$logPath = Join-Path $PSScriptRoot 'app.log'
$expectedPath = Join-Path $PSScriptRoot 'expected.csv'
$logLines = @(Get-Content -LiteralPath $logPath)
$expectedRows = @(Import-Csv -LiteralPath $expectedPath)

if ($logLines.Count -ne $expectedRows.Count) {
    throw "app.log has $($logLines.Count) lines, but expected.csv has $($expectedRows.Count) rows. Keep them aligned."
}

$pattern = '\b(disk|space|quota)\b'
$results = for ($index = 0; $index -lt $logLines.Count; $index++) {
    $expected = [bool]::Parse($expectedRows[$index].ExpectedStorageIssue)
    if ([int] $expectedRows[$index].Line -ne ($index + 1)) {
        throw "expected.csv rows must be ordered by line number. Check row $($index + 1)."
    }

    [pscustomobject]@{
        Line                 = $index + 1
        ExpectedStorageIssue = $expected
        RegexHit             = ($logLines[$index] -match $pattern)
        LogEntry             = $logLines[$index]
    }
}

if ($PassThru) {
    $results
}
else {
    Write-Host "Keyword filter: -match '$pattern'" -ForegroundColor Cyan
    $results | Format-Table Line, ExpectedStorageIssue, RegexHit, LogEntry -Wrap -AutoSize

    $falsePositives = @($results | Where-Object { $_.RegexHit -and -not $_.ExpectedStorageIssue }).Count
    $misses = @($results | Where-Object { -not $_.RegexHit -and $_.ExpectedStorageIssue }).Count
    Write-Host "Regex false positives: $falsePositives; missed storage issues: $misses" -ForegroundColor Yellow
}
