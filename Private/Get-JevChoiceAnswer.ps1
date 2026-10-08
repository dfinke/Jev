<#
.SYNOPSIS
    Reads the selected label from a named Jev Choice answer.

.DESCRIPTION
    Supports dictionary and object response shapes. Missing answers and
    missing or empty choice values remain errors.

.PARAMETER Response
    The raw Jev response containing answers.

.PARAMETER Name
    The name of the Choice question whose selected label is required.
#>
function Get-JevChoiceAnswer {
    param(
        [Parameter(Mandatory)]
        [object] $Response,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $responseFields = ConvertTo-JevDictionary -Value $Response
    if (-not $responseFields.ContainsKey('answers') -or $null -eq $responseFields['answers']) {
        throw "Jev did not return answers for question '$Name'."
    }
    $answers = ConvertTo-JevDictionary -Value $responseFields['answers']
    if (-not $answers.ContainsKey($Name) -or $null -eq $answers[$Name]) {
        throw "Jev did not return a Choice answer for question '$Name'."
    }
    $answer = ConvertTo-JevDictionary -Value $answers[$Name]
    if (-not $answer.ContainsKey('choice') -or [string]::IsNullOrWhiteSpace([string] $answer['choice'])) {
        throw "Jev did not return a Choice answer for question '$Name'."
    }

    [string] $answer['choice']
}
