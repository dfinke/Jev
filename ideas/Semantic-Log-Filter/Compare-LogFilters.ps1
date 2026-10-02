#requires -Version 7.0

<#
.SYNOPSIS
    Runs the keyword and Jev filters, then compares their results.

.DESCRIPTION
    Runs the local regex baseline and the live Jev classifier against the same
    fixture, joins results by line, and summarizes errors against expected.csv.
    Jev's uncertain results remain in a separate Review category.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Compare-LogFilters.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$regexScript = Join-Path $PSScriptRoot 'Regex-LogFilter.ps1'
$semanticScript = Join-Path $PSScriptRoot 'Semantic-LogFilter.ps1'

Write-Host 'Running the local keyword filter...' -ForegroundColor Cyan
$regexResults = @(& $regexScript -PassThru)

Write-Host "Running Jev on the same input ($($regexResults.Count) live requests)..." -ForegroundColor Cyan
$semanticResults = @(& $semanticScript -PassThru)

if ($regexResults.Count -ne $semanticResults.Count) {
    throw "The filters returned different row counts: regex=$($regexResults.Count), Jev=$($semanticResults.Count)."
}

$comparison = for ($index = 0; $index -lt $regexResults.Count; $index++) {
    $regex = $regexResults[$index]
    $semantic = $semanticResults[$index]

    if ($regex.Line -ne $semantic.Line -or $regex.ExpectedStorageIssue -ne $semantic.ExpectedStorageIssue) {
        throw "The filter outputs do not align at result row $($index + 1)."
    }

    [pscustomobject]@{
        Line                 = $regex.Line
        ExpectedStorageIssue = $regex.ExpectedStorageIssue
        RegexHit             = $regex.RegexHit
        JevProbability       = $semantic.JevProbability
        JevResult            = $semantic.JevResult
        LogEntry             = $regex.LogEntry
    }
}

Write-Host "`nSide-by-side results" -ForegroundColor Green
$comparison | Format-Table Line, ExpectedStorageIssue, RegexHit, JevProbability, JevResult, LogEntry -Wrap -AutoSize

$regexFalsePositives = @($comparison | Where-Object { $_.RegexHit -and -not $_.ExpectedStorageIssue }).Count
$regexMisses = @($comparison | Where-Object { -not $_.RegexHit -and $_.ExpectedStorageIssue }).Count
$jevIssue = @($comparison | Where-Object { $_.JevResult -eq 'Storage issue' }).Count
$jevNoIssue = @($comparison | Where-Object { $_.JevResult -eq 'No storage issue' }).Count
$jevReview = @($comparison | Where-Object { $_.JevResult -eq 'Review' }).Count
$jevAutoFalsePositives = @($comparison | Where-Object { $_.JevResult -eq 'Storage issue' -and -not $_.ExpectedStorageIssue }).Count
$jevAutoMisses = @($comparison | Where-Object { $_.JevResult -eq 'No storage issue' -and $_.ExpectedStorageIssue }).Count

Write-Host "`nAgainst the hand-labeled fixture:" -ForegroundColor Cyan
Write-Host "  Regex: $regexFalsePositives false positives; $regexMisses missed issues."
Write-Host "  Jev:   $jevIssue labeled as issues; $jevNoIssue labeled as no issue; $jevReview sent to review."
Write-Host "  Jev automatic-label mismatches: $jevAutoFalsePositives false positives; $jevAutoMisses missed issues."
Write-Host 'These labels and thresholds are for this demo; Jev results can vary, and Review is intentionally not counted as an automatic decision.' -ForegroundColor DarkGray
