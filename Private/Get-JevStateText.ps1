function Get-JevStateText {
    <# Creates a compact text representation for the deterministic mock. #>
    param(
        [Parameter(Mandatory)]
        [object] $State
    )

    if ($State -is [string]) {
        return $State
    }

    return ($State | ConvertTo-Json -Depth 20 -Compress)
}
