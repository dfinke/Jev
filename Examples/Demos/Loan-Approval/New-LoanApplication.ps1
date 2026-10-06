# Validate the fields and calculate percentages before the application reaches Jev.
function New-LoanApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 10000000)]
        [decimal] $Income,

        [Parameter(Mandatory)]
        [ValidateRange(1, 10000000)]
        [decimal] $Requested,

        [Parameter(Mandatory)]
        [ValidateRange(300, 850)]
        [int] $CreditScore,

        [Parameter(Mandatory)]
        [ValidateRange(0, 10000000)]
        [decimal] $Debt
    )

    [pscustomobject]@{
        Income                 = $Income
        Requested              = $Requested
        CreditScore            = $CreditScore
        Debt                   = $Debt
        RequestedPercentIncome = $Requested / $Income * 100
        DebtPercentIncome      = ($Debt + $Requested) / $Income * 100
    }
}
