<#
.SYNOPSIS
    Reads the probability for a named Noul answer.

.DESCRIPTION
    Supports dictionary and object answer shapes. Throws when the requested
    answer or probability is missing instead of treating a missing value as zero.

.PARAMETER Response
    The raw Jev response containing answers.

.PARAMETER Name
    The name of the Noul question whose probability is required.
#>
function Get-JevNoulProbability {
    param(
        [Parameter(Mandatory)]
        [object] $Response,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $answersProperty = $Response.PSObject.Properties['answers']
    if ($null -eq $answersProperty) {
        throw "Jev did not return answers for question '$Name'."
    }

    $answers = $answersProperty.Value
    $answer = if ($answers -is [System.Collections.IDictionary]) {
        $answers[$Name]
    }
    elseif ($null -ne $answers) {
        $answerProperty = $answers.PSObject.Properties[$Name]
        if ($null -ne $answerProperty) { $answerProperty.Value }
    }

    $probability = if ($answer -is [System.Collections.IDictionary]) {
        $answer['noul']
    }
    elseif ($null -ne $answer) {
        $probabilityProperty = $answer.PSObject.Properties['noul']
        if ($null -ne $probabilityProperty) { $probabilityProperty.Value }
    }

    if ($null -eq $probability) {
        throw "Jev did not return a Noul answer for question '$Name'."
    }

    [double] $probability
}
