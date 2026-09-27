<#
.SYNOPSIS
    Evaluates Jev answers against the three-tier behavioral confidence model.

.DESCRIPTION
    Implements the 3-tier behavioral model defined in Jev best practices:
      - High confidence (>= 0.8) -> 'Act' (act automatically)
      - Medium confidence (0.5 - 0.8) -> 'Review' (confirm, flag, or gather info)
      - Low confidence (< 0.5) -> 'Escalate' (route to human / do not act)

    Supports risk-scaled thresholds ('Low', 'Standard', 'High') to raise or lower
    the bar depending on the consequences of an automated decision.

.PARAMETER InputObject
    An enriched Jev result object or an individual question answer.

.PARAMETER QuestionName
    The name of the question to evaluate if InputObject is an enriched result.
    If omitted and only one question answer is present, it is automatically selected.

.PARAMETER HighThreshold
    Custom threshold for the 'Act' tier. Defaults to 0.8 (or risk-adjusted).

.PARAMETER MediumThreshold
    Custom threshold for the 'Review' tier. Defaults to 0.5 (or risk-adjusted).

.PARAMETER RiskLevel
    Risk-scaling profile: 'Low' (low stakes, relaxed thresholds 0.7/0.4),
    'Standard' (0.8/0.5), or 'High' (high stakes, strict thresholds 0.9/0.7).

.EXAMPLE
    $decision = 'Checkout failed' | Invoke-Jev -Question $q -Mock
    $decision | Get-JevConfidenceTier
#>
function Get-JevConfidenceTier {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $InputObject,
        [string] $QuestionName,
        [double] $HighThreshold,
        [double] $MediumThreshold,
        [ValidateSet('Low', 'Standard', 'High')]
        [string] $RiskLevel = 'Standard'
    )
    process {
        $effectiveHigh = if ($PSBoundParameters.ContainsKey('HighThreshold')) {
            $HighThreshold
        }
        else {
            switch ($RiskLevel) {
                'Low'      { 0.7 }
                'High'     { 0.9 }
                default    { 0.8 }
            }
        }
        $effectiveMedium = if ($PSBoundParameters.ContainsKey('MediumThreshold')) {
            $MediumThreshold
        }
        else {
            switch ($RiskLevel) {
                'Low'      { 0.4 }
                'High'     { 0.7 }
                default    { 0.5 }
            }
        }
        $answerObj  = $null
        $targetName = $QuestionName
        if ($InputObject.PSObject.Properties['answers']) {
            $answers = $InputObject.answers
            if ([string]::IsNullOrWhiteSpace($targetName)) {
                $keys = @($answers.Keys)
                if ($keys.Count -eq 1) {
                    $targetName = $keys[0]
                }
                else {
                    throw "Multiple answers present ($($keys -join ', ')). Please specify -QuestionName."
                }
            }
            $answerObj = $answers[$targetName]
        }
        elseif ($InputObject.PSObject.Properties['type']) {
            $answerObj = $InputObject
            if ([string]::IsNullOrWhiteSpace($targetName)) {
                $targetName = 'answer'
            }
        }
        else {
            throw 'InputObject must be an enriched Jev result or an answer object.'
        }
        $answerType = ([string] $answerObj.type).ToLowerInvariant()
        $confidence = 0.0
        $value = $null
        switch ($answerType) {
            'choice' {
                $value = $answerObj.choice
                $confidence = [double] $answerObj.confidence
            }
            'score' {
                $value = $answerObj.score
                $confidence = [double] $answerObj.confidence
            }
            'noul' {
                $value = [double] $answerObj.noul
                # For Noul, distance from 0.5 represents confidence
                $confidence = [math]::Round([math]::Abs($value - 0.5) * 2.0, 4)
            }
            default {
                throw "Unsupported answer type '$answerType'."
            }
        }
        $tier = if ($confidence -ge $effectiveHigh) {
            'Act'
        }
        elseif ($confidence -ge $effectiveMedium) {
            'Review'
        }
        else {
            'Escalate'
        }
        [pscustomobject] [ordered] @{
            Question          = $targetName
            Type              = $answerType
            Value             = $value
            Confidence        = [math]::Round($confidence, 4)
            Tier              = $tier
            ShouldAct         = ($tier -eq 'Act')
            RiskLevel         = $RiskLevel
            HighThreshold     = $effectiveHigh
            MediumThreshold   = $effectiveMedium
        }
    }
}
