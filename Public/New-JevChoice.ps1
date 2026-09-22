<##
.SYNOPSIS
    Creates a named choice that can be supplied as Choice criteria.

.DESCRIPTION
    New-JevQuestion converts these convenience objects into the JSON
    criteria dictionary used by a Choice question.
#>
function New-JevChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Description
    )

    [pscustomobject] [ordered] @{
        Name        = $Name
        Description = $Description
    }
}
