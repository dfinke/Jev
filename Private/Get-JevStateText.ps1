<#
.SYNOPSIS
    Converts a state value to compact text for the local mock.

.PARAMETER State
    The string or object to represent as text.
#>
function Get-JevStateText {
    param(
        [Parameter(Mandatory)]
        [object] $State
    )

    if ($State -is [string]) {
        return $State
    }

    return ($State | ConvertTo-Json -Depth 20 -Compress)
}
