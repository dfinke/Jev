<#
.SYNOPSIS
    Creates a typed Jev Choice question definition.

.DESCRIPTION
    A friendly way to construct a Choice question. Choices maps to criteria
    in the Jev payload. Supports automatic fallback handling (to ensure a no-match
    option exists as recommended by Jev best practices) and structured criteria
    for contrastive disambiguation.

.PARAMETER Name
    The key used to identify this question's answer in the response.

.PARAMETER Instructions
    The question instructions sent to Jev.

.PARAMETER Choices
    A hashtable of option names to descriptions or structured criteria.

.PARAMETER FallbackDescription
    Optional description for a fallback choice. If provided, automatically
    adds an 'other' or 'none_of_the_above' entry if one does not already exist.

.PARAMETER AllowOther
    When specified, automatically adds 'other' = 'None of the above' to choices
    if not already defined.

.EXAMPLE
    $question = New-JevChoiceQuestion -Name route `
        -Instructions 'Which team should handle this ticket?' `
        -Choices @{
            billing   = 'Payment, subscription, or invoice issues.'
            technical = 'Bugs, API errors, or integration problems.'
            sales     = 'Pricing, upgrades, or new account questions.'
        } -AllowOther
#>
function New-JevChoiceQuestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        [Parameter(Mandatory, Position = 1)]
        [Alias('Prompt', 'Question')]
        [object] $Instructions,
        [Parameter(Mandatory, Position = 2)]
        [System.Collections.IDictionary] $Choices,
        [string] $FallbackDescription,
        [switch] $AllowOther
    )

    $criteria = [ordered]@{}
    foreach ($key in $Choices.Keys) {
        $criteria[[string] $key] = $Choices[$key]
    }
    if ($AllowOther.IsPresent -and 
        -not $criteria.Contains('other') -and 
        -not $criteria.Contains('unknown') -and 
        -not $criteria.Contains('none_of_the_above')) {
        $criteria['other'] = 'None of the above.'
    }
    elseif ($FallbackDescription) {
        $fallbackKey = if (-not $criteria.Contains('other')) {
            'other'
        }
        elseif (-not $criteria.Contains('none_of_the_above')) {
            'none_of_the_above'
        }
        else {
            'fallback'
        }
        $criteria[$fallbackKey] = $FallbackDescription
    }
    New-JevQuestion -Name $Name -Type Choice -Instructions $Instructions -Criteria $criteria
}
