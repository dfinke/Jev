<##
.SYNOPSIS
    Creates a typed Jev question definition.

.DESCRIPTION
    The parameter names mirror the question object sent in the Jev JSON
    payload: type, instructions, and criteria. Name becomes the key in the
    request's questions dictionary.

.PARAMETER Name
    The name used to identify the answer in the response.

.PARAMETER Type
    The JSON question type: Noul, Choice, or Score.

.PARAMETER Instructions
    The question instructions sent to Jev.

.PARAMETER Criteria
    Type-specific criteria. Use a true/false dictionary for Noul, a
    name-to-description dictionary for Choice, or an ordered array for Score.

.EXAMPLE
    New-JevQuestion -Name urgency -Type Score `
        -Instructions 'How urgent is this?' `
        -Criteria @('Can wait', 'This week', 'Today')
#>
function New-JevQuestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateSet('Noul', 'Choice', 'Score')]
        [string] $Type,

        [Parameter(Mandatory)]
        [Alias('Prompt')]
        [object] $Instructions,

        [AllowNull()]
        [object] $Criteria
    )

    $criteriaCount = if ($null -eq $Criteria) {
        0
    }
    elseif ($Criteria -is [System.Collections.IDictionary]) {
        $Criteria.Count
    }
    else {
        @($Criteria).Count
    }

    if ($Type -eq 'Score' -and $criteriaCount -lt 2) {
        throw "Score question '$Name' requires at least two -Criteria values."
    }

    if ($Type -eq 'Score' -and $criteriaCount -gt 10) {
        throw "Score question '$Name' cannot have more than 10 -Criteria values."
    }

    if ($Type -eq 'Choice' -and $criteriaCount -eq 0) {
        throw "Choice question '$Name' requires at least one -Criteria entry."
    }

    if ($Type -eq 'Choice' -and $criteriaCount -gt 255) {
        throw "Choice question '$Name' cannot have more than 255 -Criteria entries."
    }

    if ($Type -eq 'Noul' -and $null -ne $Criteria -and $Criteria -isnot [System.Collections.IDictionary]) {
        throw "Noul question '$Name' requires -Criteria to be a dictionary with true and false keys."
    }

    if ($Type -eq 'Choice' -and $null -ne $Criteria -and $Criteria -isnot [System.Collections.IDictionary]) {
        throw "Choice question '$Name' requires -Criteria to be a name-to-description dictionary."
    }

    if ($Type -eq 'Noul' -and $null -ne $Criteria) {
        $criteriaKeys = @($Criteria.Keys | ForEach-Object { [string] $_ })
        if ($criteriaKeys | Where-Object { $_ -notin @('true', 'false') }) {
            throw "Noul question '$Name' accepts only true and false -Criteria keys."
        }
    }

    $normalizedCriteria = $Criteria
    if ($Type -eq 'Score' -and $null -ne $Criteria) {
        $normalizedCriteria = @($Criteria)
    }

    [pscustomobject] [ordered] @{
        Name         = $Name
        Type         = $Type
        Instructions = $Instructions
        Criteria     = $normalizedCriteria
    }
}
