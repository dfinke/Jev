# Jev selects the rule. PowerShell maps its label to a bounded output object.
function Get-LoanDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject] $State
    )

    begin {
        . "$PSScriptRoot/New-LoanApplication.ps1"
        Import-Module Jev -ErrorAction Stop
        $loanModel = & "$PSScriptRoot/LoanModel.ps1"
    }

    process {
        # Refresh the percentages in case a field changed after construction.
        $application = New-LoanApplication -Income $State.Income -Requested $State.Requested `
            -CreditScore $State.CreditScore -Debt $State.Debt
        $response = Invoke-Jev -State $application -Question $loanModel.Question `
            -Model $loanModel.Model -Raw -ErrorAction Stop
        $selected = [string] $response.answers.outcome.choice
        if (-not $loanModel.Outcomes.Contains($selected)) {
            throw "Jev returned an unknown loan outcome: '$selected'."
        }
        $outcome = $loanModel.Outcomes[$selected]

        [pscustomobject]@{
            Decision = $outcome.Decision
            Reason   = $outcome.Reason
        }
    }
}
