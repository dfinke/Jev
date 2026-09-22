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
