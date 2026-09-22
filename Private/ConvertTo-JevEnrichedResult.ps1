function ConvertTo-JevEnrichedResult {
    param(
        [Parameter(Mandatory)]
        [object] $State,

        [Parameter(Mandatory)]
        [object] $Response
    )

    $result = [ordered]@{}

    if ($State -is [System.Collections.IDictionary]) {
        foreach ($key in $State.Keys) {
            $name = [string] $key
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $result[$name] = $State[$key]
        }
    }
    elseif ($State -is [string] -or $State -is [ValueType] -or $State -is [Array]) {
        $result['State'] = $State
    }
    else {
        foreach ($property in $State.PSObject.Properties) {
            $result[$property.Name] = $property.Value
        }
    }

    foreach ($property in $Response.PSObject.Properties) {
        $name = $property.Name
        if ($result.Contains($name)) {
            $name = "Jev_$name"
        }
        $result[$name] = $property.Value
    }

    [pscustomobject] $result
}
