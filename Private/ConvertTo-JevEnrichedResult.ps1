<#
.SYNOPSIS
    Combines the original state with Jev's answer values and response details.

.DESCRIPTION
    Promotes named answers to top-level properties and preserves the full
    answers and usage objects. Prefixes Jev properties when names collide
    with properties already present on the state.

.PARAMETER State
    The original value sent to Jev.

.PARAMETER Response
    The response returned by Jev.
#>
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

    foreach ($property in $Response.PSObject.Properties | Where-Object Name -notin @('answers', 'usage')) {
        $name = $property.Name
        if ($result.Contains($name)) {
            $name = "Jev_$name"
        }
        $result[$name] = $property.Value
    }

    $answersProperty = $Response.PSObject.Properties['answers']
    if ($null -ne $answersProperty) {
        $answerEntries = if ($answersProperty.Value -is [System.Collections.IDictionary]) {
            @($answersProperty.Value.GetEnumerator() | ForEach-Object {
                [pscustomobject] @{ Name = [string] $_.Key; Value = $_.Value }
            })
        }
        else {
            @($answersProperty.Value.PSObject.Properties | ForEach-Object {
                [pscustomobject] @{ Name = $_.Name; Value = $_.Value }
            })
        }

        foreach ($answerEntry in $answerEntries) {
            $answerValue = $answerEntry.Value
            $displayValue = $answerValue
            $answerType = [string] $answerValue.type
            switch ($answerType.ToLowerInvariant()) {
                'noul' { $displayValue = $answerValue.noul }
                'choice' { $displayValue = $answerValue.choice }
                'score' { $displayValue = $answerValue.score }
            }

            $name = $answerEntry.Name
            while ($result.Contains($name)) {
                $name = "Jev_$name"
            }
            $result[$name] = $displayValue
        }
    }

    $usageProperty = $Response.PSObject.Properties['usage']
    if ($null -ne $usageProperty) {
        $name = 'usage'
        while ($result.Contains($name)) {
            $name = "Jev_$name"
        }
        $result[$name] = $usageProperty.Value
    }

    if ($null -ne $answersProperty) {
        $name = 'answers'
        while ($result.Contains($name)) {
            $name = "Jev_$name"
        }
        $result[$name] = $answersProperty.Value
    }

    [pscustomobject] $result
}
