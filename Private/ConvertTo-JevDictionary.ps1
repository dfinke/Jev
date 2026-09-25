<#
.SYNOPSIS
    Converts a hashtable or PSCustomObject to a string-keyed dictionary.

.PARAMETER Value
    The dictionary or PSCustomObject to convert.
#>
function ConvertTo-JevDictionary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Value
    )

    if ($Value -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($entry in $Value.GetEnumerator()) {
            $result[[string] $entry.Key] = $entry.Value
        }
        return $result
    }

    if ($Value -is [pscustomobject]) {
        $result = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = $property.Value
        }
        return $result
    }

    throw "Expected a hashtable or PSCustomObject, but received '$($Value.GetType().FullName)'."
}
