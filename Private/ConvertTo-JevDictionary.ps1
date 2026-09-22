function ConvertTo-JevDictionary {
    <# Converts a hashtable or PSCustomObject into an ordered dictionary. #>
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
