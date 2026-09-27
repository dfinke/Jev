<#
.SYNOPSIS
    Creates a structured criterion definition for contrastive disambiguation.

.DESCRIPTION
    Builds a structured dictionary with 'what', 'not_for', and 'examples'
    fields as described in the Jev question design rules. Useful when simple
    string descriptions blur together or when options require explicit boundaries.

.PARAMETER What
    Positive description of what this option covers.

.PARAMETER NotFor
    Contrastive description of what this option does NOT cover.

.PARAMETER Examples
    Concrete example queries or phrases illustrating this option.
    
.EXAMPLE
    $limitsCriterion = New-JevCriterion `
        -What 'Quantity, transaction, or merchant restrictions' `
        -NotFor 'Purpose, eligibility, or setup' `
        -Examples @('How many cards per day?', 'Where can I use it?')
#>
function New-JevCriterion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $What,
        [Parameter(Position = 1)]
        [string] $NotFor,
        [Parameter(Position = 2)]
        [string[]] $Examples
    )

    $criterion = [ordered]@{
        what = $What
    }
    if (-not [string]::IsNullOrWhiteSpace($NotFor)) {
        $criterion['not_for'] = $NotFor
    }
    if ($null -ne $Examples -and 
        @($Examples).Count -gt 0) {
        $criterion['examples'] = @($Examples)
    }

    $criterion
}
