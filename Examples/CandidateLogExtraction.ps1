#requires -Version 7.0
<#
.SYNOPSIS
    Demonstrates the 'Select Instead of Generate' / Reranking pattern from Jev skills.

.DESCRIPTION
    Instead of asking an LLM to generate free-form text or reason about root causes,
    PowerShell extracts candidate error spans or log statements in code, then asks
    Jev to score and select the best candidate.
    
.EXAMPLE
    .\CandidateLogExtraction.ps1
#>
[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

# Raw diagnostic log from a failing microservice deployment
$logDump = @'
2026-09-26 13:10:01 INFO  [WebWorker] Listening on port 8080.
2026-09-26 13:10:03 DEBUG [AuthService] Token cache initialized.
2026-09-26 13:10:05 WARN  [ConfigLoader] Optional environment variable METRICS_PORT not set, defaulting to 9090.
2026-09-26 13:10:08 ERROR [DatabasePool] Npgsql.NpgsqlException: Connection refused (0x0000274D/10061) to host 'pg-cluster-prod.internal:5432'.
2026-09-26 13:10:09 ERROR [HealthCheck] Database connection check failed after 3000ms.
2026-09-26 13:10:11 FATAL [Main] Application failed to start. Terminating process.
'@

Write-Host "Extracting error candidates from diagnostic log..." -ForegroundColor Cyan

# Step 1: Extract candidate error lines in code
$candidateLines = $logDump -split "`r?`n" | Where-Object { $_ -match 'ERROR|FATAL|WARN' }
Write-Host "Found $($candidateLines.Count) candidate log entries:`n"

# Step 2: Use Jev to rerank and select the primary root cause
$query = "Which log entry describes the foundational root cause of the application startup failure?"

$rankedErrors = $candidateLines | Invoke-JevRerank -Query $query -Top 3 -MockOnMissingKey
Write-Host "Top Ranked Root Causes (Selected by Jev):" -ForegroundColor Green
$rankedErrors | Format-Table @{
    Name = 'Relevance'
    Expression = { "$([math]::Round($_.JevRelevance, 2))" }
}, @{
    Name = 'Confidence'
    Expression = { "$([math]::Round($_.JevConfidence, 2))" }
}, @{
    Name = 'Log Line'
    Expression = { $_.Value }
} -AutoSize
# Step 3: Act on the top candidate in code
$topCandidate = $rankedErrors | Select-Object -First 1
if ($topCandidate.Value -match 'pg-cluster-prod.internal:5432') {
    Write-Host "`nAutomated Remediation Triggered: Verifying PostgreSQL cluster status & network security groups." -ForegroundColor Magenta
}
