function New-JevQuestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateSet('Noul', 'Choice', 'Score')]
        [string] $Type,

        [Parameter(Mandatory)]
        [Alias('Instructions')]
        [object] $Prompt,

        [object[]] $Level,

        [object[]] $Choice,

        [AllowNull()]
        [object] $TrueCriteria,

        [AllowNull()]
        [object] $FalseCriteria
    )

    $levelCount = if ($null -eq $Level) { 0 } else { $Level.Count }
    $choiceCount = if ($null -eq $Choice) { 0 } else { $Choice.Count }

    if ($Type -eq 'Score' -and $levelCount -lt 2) {
        throw "Score question '$Name' requires at least two -Level values."
    }

    if ($Type -eq 'Score' -and $levelCount -gt 10) {
        throw "Score question '$Name' cannot have more than 10 -Level values."
    }

    if ($Type -eq 'Choice' -and $choiceCount -eq 0) {
        throw "Choice question '$Name' requires at least one -Choice."
    }

    if ($Type -eq 'Choice' -and $choiceCount -gt 255) {
        throw "Choice question '$Name' cannot have more than 255 -Choice values."
    }

    if ($Type -ne 'Noul' -and ($PSBoundParameters.ContainsKey('TrueCriteria') -or $PSBoundParameters.ContainsKey('FalseCriteria'))) {
        throw "Only Noul question '$Name' accepts -TrueCriteria or -FalseCriteria."
    }

    if ($Type -eq 'Noul' -and ($levelCount -gt 0 -or $choiceCount -gt 0)) {
        throw "Noul question '$Name' does not accept -Level or -Choice."
    }

    [pscustomobject] [ordered] @{
        Name          = $Name
        Type          = $Type
        Instructions  = $Prompt
        Level         = @($Level)
        Choice        = @($Choice)
        TrueCriteria  = $TrueCriteria
        FalseCriteria = $FalseCriteria
    }
}
