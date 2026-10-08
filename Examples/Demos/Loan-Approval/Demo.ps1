# PowerShell calculates percentages; Jev applies the editable policy to those facts.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/New-LoanApplication.ps1"
. "$PSScriptRoot/Get-LoanDecision.ps1"

$state = New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000

Write-Host 'Initial state: expect Approve.' -ForegroundColor Cyan
$state | Get-LoanDecision | Format-Table -AutoSize | Out-Host

$state.CreditScore = 640
Write-Host 'Changed only CreditScore to 640: expect Refer.' -ForegroundColor Cyan
$state | Get-LoanDecision | Format-Table -AutoSize | Out-Host

$states = @(Import-Csv "$PSScriptRoot/Applications.csv" | ForEach-Object {
    $loanParameters = @{
        Income      = $_.Income
        Requested   = $_.Requested
        CreditScore = $_.CreditScore
        Debt        = $_.Debt
    }
    New-LoanApplication @loanParameters
})

Write-Host "$($states.Count) applications from CSV through the same model:" -ForegroundColor Cyan
$results = @($states | Get-LoanDecision)
$results
