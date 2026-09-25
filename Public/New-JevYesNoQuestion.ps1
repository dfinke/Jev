<#
.SYNOPSIS
    Creates a Jev yes/no question.

.DESCRIPTION
    A friendly way to create a Noul question. Question maps to Jev's
    instructions field; TrueCriteria and FalseCriteria become the true and
    false entries in criteria. The Noul answer is a probability of true; the
    caller decides how to display or act on it. Use New-JevQuestion for direct
    access to the Jev payload fields and other question types.

.PARAMETER Name
    The key used to identify this question's answer in the response.

.PARAMETER Question
    The yes/no question Jev should answer. Maps to instructions in the payload.

.PARAMETER TrueCriteria
    Describes the evidence that supports a yes answer.

.PARAMETER FalseCriteria
    Describes the evidence that supports a no answer.

.EXAMPLE
    $question = New-JevYesNoQuestion -Name pageOnCall `
        -Question 'Should the on-call engineer be paged now?' `
        -TrueCriteria 'Customers cannot complete purchases' `
        -FalseCriteria 'Purchases are working normally'

    @(
        'Checkout is returning HTTP 503 errors; customers cannot place orders.'
        'Checkout is healthy; customers are placing orders normally with no errors.'
    ) | Invoke-Jev -Question $question | Select-Object State, @{
        Name       = 'pageOnCall'
        Expression = { if ($_.pageOnCall -ge 0.8) { 'page' } else { 'do not page' } }
    }

    Shows a readable action for each incident. The 0.8 cutoff is an example
    policy; the underlying Noul answer remains a probability.
#>
function New-JevYesNoQuestion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Question,

        [Parameter(Mandatory)]
        [string] $TrueCriteria,

        [Parameter(Mandatory)]
        [string] $FalseCriteria
    )

    New-JevQuestion -Name $Name -Type Noul -Instructions $Question -Criteria @{
        true  = $TrueCriteria
        false = $FalseCriteria
    }
}
