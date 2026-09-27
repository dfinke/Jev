<#
.SYNOPSIS
    Calculates weighted composite scores and enforces hard policy overrides across Jev answers.

.DESCRIPTION
    Combines multiple independent Noul (probabilities) and Score (levels) answers
    into a unified composite score. Normalizes ordered Score levels to a 0-1 scale,
    applies caller-defined weights, and evaluates hard rule overrides (e.g. blocking
    an action if a policy violation probability exceeds 0.9).

.PARAMETER InputObject
    An enriched Jev result object containing promoted answer properties.

.PARAMETER Weights
    A hashtable specifying relative weights for answer properties (e.g. @{ urgency = 0.6; severity = 0.4 }).

.PARAMETER ScoreMaxLevels
    An optional hashtable mapping Score property names to their maximum level index (levels count - 1)
    to normalize the score between 0 and 1. If omitted, attempts to auto-detect from the answer's legend.

.PARAMETER Overrides
    An array of hashtable rules that override the composite calculation when met.
    Each override can specify:
      - Property: The answer property to check
      - Threshold: The cutoff value
      - Comparison: 'GreaterThan' (default), 'LessThan', 'GreaterThanOrEqual', 'LessThanOrEqual'
      - Action: The action or label to return if the condition matches

.EXAMPLE
    $decision | Measure-JevScore -Weights @{
        bug_severity = 0.5
        customer_frustration = 0.3
        report_quality = 0.2
    }
#>
function Measure-JevScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $InputObject,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Weights,
        [System.Collections.IDictionary] $ScoreMaxLevels,
        [object[]] $Overrides
    )

    process {
        # Check hard overrides first
        if ($Overrides) {
            foreach ($ov in $Overrides) {
                $prop       = [string] $ov['Property']
                $threshold  = [double] $ov['Threshold']
                $action     = [string] $ov['Action']
                $comp       = if ($ov.ContainsKey('Comparison')) { 
                                    [string] $ov['Comparison'] 
                                    } else { 'GreaterThan' }

                $propVal = $InputObject.PSObject.Properties[$prop]
                if ($null -ne $propVal -and 
                    $null -ne $propVal.Value) {
                    $val = [double] $propVal.Value
                    $matched = switch ($comp) {
                        'GreaterThan'          { $val -gt $threshold }
                        'GreaterThanOrEqual'   { $val -ge $threshold }
                        'LessThan'             { $val -lt $threshold }
                        'LessThanOrEqual'      { $val -le $threshold }
                        default                { $val -gt $threshold }
                    }
                    if ($matched) {
                        return [pscustomobject] [ordered] @{
                            CompositeScore      = $val
                            NormalizedScore     = [math]::Round($val, 4)
                            IsOverride          = $true
                            AppliedOverride     = $action
                            TriggerProperty     = $prop
                            ContributingFactors = @{ $prop = $val }
                        }
                    }
                }
            }
        }

        # Calculate weighted composite score
        $totalWeight = 0.0
        $weightedSum = 0.0
        $contributing = [ordered]@{}

        foreach ($entry in $Weights.GetEnumerator()) {
            $propName   = [string] $entry.Key
            $weight     = [double] $entry.Value

            if ($weight -le 0) { continue }
            $prop = $InputObject.PSObject.Properties[$propName]
            if ($null -eq $prop -or 
                $null -eq $prop.Value) {
                continue
            }
            $rawVal         = [double] $prop.Value
            $normalizedVal  = $rawVal

            # Check if this is a Score question that needs normalization
            $maxLevel = $null
            if ($null -ne $ScoreMaxLevels -and $ScoreMaxLevels.Contains($propName)) {
                $maxLevel = [double] $ScoreMaxLevels[$propName]
            }
            elseif ($InputObject.PSObject.Properties['answers'] -and 
                    $InputObject.answers.PSObject.Properties[$propName]) {
                $ans = $InputObject.answers.$propName
                if ($ans.PSObject.Properties['type'] -and 
                    [string]$ans.type -eq 'score'   -and $ans.PSObject.Properties['legend']) {
                    $maxLevel = [double] ($ans.legend.Keys.Count - 1)
                }
            }

            if ($null -ne $maxLevel -and 
                $maxLevel -gt 0) {
                $normalizedVal = $rawVal / $maxLevel
            }

            # Clamp normalized value between 0 and 1
            $normalizedVal  = [math]::Max(0.0, [math]::Min(1.0, $normalizedVal))
            $totalWeight    += $weight
            $weightedSum    += ($normalizedVal * $weight)
            $contributing[$propName] = [math]::Round($normalizedVal, 4)
        }

        $composite = if ($totalWeight -gt 0) {
            $weightedSum / $totalWeight
        }
        else {
            0.0
        }

        [pscustomobject] [ordered] @{
            CompositeScore      = [math]::Round($composite, 4)
            NormalizedScore     = [math]::Round($composite, 4)
            IsOverride          = $false
            AppliedOverride     = $null
            TriggerProperty     = $null
            ContributingFactors = $contributing
        }
    }
}
