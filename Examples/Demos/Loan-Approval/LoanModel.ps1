# Load the editable policy; keep the provider and output mapping in PowerShell.
. "$PSScriptRoot/Import-LoanPolicy.ps1"
$policy = Import-LoanPolicy

$outcomes = [ordered]@{
    'Amount too high' = [pscustomobject]@{ Decision = 'Deny'; Reason = 'Amount over half of income' }
    'Credit review'   = [pscustomobject]@{ Decision = 'Refer'; Reason = 'Credit score below 680' }
    'Debt too high'   = [pscustomobject]@{ Decision = 'Deny'; Reason = 'DTI over 0.4' }
    'Approve'         = [pscustomobject]@{ Decision = 'Approve'; Reason = 'All approval conditions met' }
}

if ($policy.Criteria.Count -ne $outcomes.Count) {
    throw 'Policy choices must match the four outcome names in LoanModel.ps1.'
}
foreach ($name in $policy.Criteria.Keys) {
    if (-not $outcomes.Contains($name)) {
        throw "Policy choice '$name' has no decision/reason mapping in LoanModel.ps1."
    }
}

$question = New-JevQuestion -Name outcome -Type Choice `
    -Instructions $policy.Instructions -Criteria $policy.Criteria

[pscustomobject]@{
    Model    = 'jev-1.13.0'
    Question = $question
    Outcomes = $outcomes
}
