<#
.SYNOPSIS
    Tests each input state against a yes/no Jev question.

.DESCRIPTION
    Demo-local helper using the Jev module's public commands. Returns one
    Boolean per pipeline item, with one live Jev request for each item.

.PARAMETER State
    The string or object Jev should evaluate. Accepts pipeline input.

.PARAMETER Question
    The yes/no question Jev should answer.

.PARAMETER Threshold
    The minimum probability of true required to return $true. Defaults to 0.5.

.EXAMPLE
    'Please refund the duplicate charge.' | Test-Jev 'Does the customer ask for a refund?'
#>
function Test-Jev {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [string] $Question,

        [Parameter(Position = 1)]
        [ValidateRange(0.0, 1.0)]
        [double] $Threshold = 0.5
    )

    begin {
        $questionDefinition = New-JevQuestion -Name answer -Type Noul -Instructions $Question
    }

    process {
        $result = Invoke-Jev -State $State -Question $questionDefinition
        [double] $result.answers.answer.noul -ge $Threshold
    }
}
