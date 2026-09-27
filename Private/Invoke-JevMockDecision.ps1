<#
.SYNOPSIS
    Creates deterministic, schema-compatible answers without an API call.

.DESCRIPTION
    Checks caller-registered mock rules first. If no matching rule is found,
    evaluates built-in heuristics. Makes pipeline and integration behavior
    testable offline.

.PARAMETER State
    The input state used by the mock rules.

.PARAMETER Questions
    The normalized, named Jev questions to answer.

.PARAMETER Model
    The model name to include in the mock response.
#>

if (-not (Get-Variable -Name 'JevMockRules' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:JevMockRules = [System.Collections.Generic.List[object]]::new()
}

function Invoke-JevMockDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $State,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Questions,

        [Parameter(Mandatory)]
        [string] $Model
    )

    $text = Get-JevStateText -State $State
    $answers = [ordered] @{}

    foreach ($questionEntry in $Questions.GetEnumerator()) {
        $name = [string] $questionEntry.Key
        if ($null -eq $questionEntry.Value) {
            throw "Question '$name' cannot be null."
        }
        $question = ConvertTo-JevDictionary -Value $questionEntry.Value
        $type = ([string] $question.type).ToLowerInvariant()

        # Check caller-registered dynamic mock rules first
        $matchedRule = $null
        if ($script:JevMockRules -and $script:JevMockRules.Count -gt 0) {
            foreach ($rule in $script:JevMockRules) {
                if ($rule.QuestionName -eq $name) {
                    try {
                        if (& $rule.Matcher $State) {
                            $matchedRule = $rule
                            break
                        }
                    }
                    catch {
                        # Continue if matcher encounters evaluation error
                    }
                }
            }
        }

        if ($null -ne $matchedRule) {
            switch ($type) {
                'noul' {
                    $answers[$name] = [pscustomobject] [ordered] @{
                        type = 'noul'
                        noul = [math]::Round([double] $matchedRule.Answer, 4)
                    }
                }
                'choice' {
                    $criteria = ConvertTo-JevDictionary -Value $question.criteria
                    $keys = @($criteria.Keys | ForEach-Object { [string] $_ })
                    $selectedChoice = [string] $matchedRule.Answer
                    $selectedIndex = [array]::IndexOf($keys, $selectedChoice)
                    if ($selectedIndex -lt 0) { $selectedIndex = 0; $selectedChoice = $keys[0] }
                    $answers[$name] = [pscustomobject] [ordered] @{
                        type          = 'choice'
                        choice        = $selectedChoice
                        confidence    = [double] $matchedRule.Confidence
                        probabilities = New-JevProbabilityDistribution -Keys $keys -SelectedIndex $selectedIndex
                    }
                }
                'score' {
                    $levels = @($question.criteria)
                    $selectedScore = [double] $matchedRule.Answer
                    $selectedIndex = [math]::Min($levels.Count - 1, [math]::Max(0, [int] [math]::Round($selectedScore)))
                    $levelKeys = @($levels | ForEach-Object { [string] ([array]::IndexOf($levels, $_)) })
                    $legend = [ordered] @{}
                    for ($index = 0; $index -lt $levels.Count; $index++) {
                        $legend[[string] $index] = $levels[$index]
                    }
                    $answers[$name] = [pscustomobject] [ordered] @{
                        type          = 'score'
                        score         = [math]::Round($selectedScore, 2)
                        confidence    = [double] $matchedRule.Confidence
                        legend        = $legend
                        probabilities = New-JevProbabilityDistribution -Keys $levelKeys -SelectedIndex $selectedIndex
                    }
                }
            }
        }
        else {
            # Fallback to built-in heuristic rules
            switch ($type) {
                'noul' {
                    $instructions = if ($question.Contains('instructions')) { [string] $question.instructions } else { '' }
                    $questionText = "$name $instructions $text".ToLowerInvariant()
                    $signal = $false

                    if ($questionText -match 'security|critical|attack|breach|credential|unauthori[sz]ed|brute|injection|malware|ransom') {
                        $signal = $text -match 'security|attack|breach|credential|unauthori[sz]ed|brute|injection|malware|ransom|privilege|token'
                    }
                    elseif ($questionText -match 'churn|leav|cancel|retention') {
                        $signal = $text -match 'cancel|leav|switch|competitor|unacceptable|losing (?:sales|business)|refund|downgrade'
                    }
                    elseif ($questionText -match 'urgent|active|threat|risk') {
                        $signal = $text -match 'urgent|asap|immediately|blocked|outage|down|critical|losing|breach|attack'
                    }
                    else {
                        $signal = $text -match 'yes|true|critical|urgent|blocked|breach|attack'
                    }

                    $probability = if ($signal) { 0.93 } else { 0.08 }
                    $answers[$name] = [pscustomobject] [ordered] @{
                        type = 'noul'
                        noul = $probability
                    }
                }

                'choice' {
                    $criteria = ConvertTo-JevDictionary -Value $question.criteria
                    $keys = @($criteria.Keys | ForEach-Object { [string] $_ })
                    $lowerText = $text.ToLowerInvariant()
                    $selectedIndex = 0
                    $matched = $false

                    for ($index = 0; $index -lt $keys.Count; $index++) {
                        $key = $keys[$index].ToLowerInvariant()
                        $keyPattern = [regex]::Escape($key)

                        $keyMatch = switch -Regex ($key) {
                            'auth|credential|access|identity|permission' { $lowerText -match 'auth|login|password|credential|token|permission|unauthori[sz]ed' }
                            'network|connect|timeout|transport' { $lowerText -match 'network|timeout|connection|connect|dns|socket|refused|unreachable' }
                            'syntax|parse|format|json|command' { $lowerText -match 'syntax|parse|invalid json|unexpected token|parser|command not found' }
                            'restart|reboot' { $lowerText -match 'restart|reboot|start over' }
                            'status|health|check' { $lowerText -match 'status|health|is .*up|running' }
                            'log|tail|diagnos' { $lowerText -match 'log|logs|diagnos|trace' }
                            'deploy|release|publish' { $lowerText -match 'deploy|release|publish|ship' }
                            'help|unknown|other' { $false }
                            default { $lowerText -match $keyPattern }
                        }

                        if ($keyMatch) {
                            $selectedIndex = $index
                            $matched = $true
                            break
                        }
                    }

                    if (-not $matched) {
                        $unknownIndex = [array]::IndexOf($keys, 'unknown')
                        if ($unknownIndex -lt 0) { $unknownIndex = [array]::IndexOf($keys, 'help') }
                        if ($unknownIndex -ge 0) { $selectedIndex = $unknownIndex }
                    }

                    $selectedChoice = $keys[$selectedIndex]
                    $answers[$name] = [pscustomobject] [ordered] @{
                        type          = 'choice'
                        choice        = $selectedChoice
                        confidence    = if ($matched) { 0.91 } else { 0.56 }
                        probabilities = New-JevProbabilityDistribution -Keys $keys -SelectedIndex $selectedIndex
                    }
                }

                'score' {
                    $levels = @($question.criteria)
                    $lowerText = $text.ToLowerInvariant()
                    $selectedIndex = 0

                    if ($levels.Count -gt 1 -and $lowerText -match 'urgent|asap|immediately|blocked|outage|down|critical|losing') {
                        $selectedIndex = $levels.Count - 1
                    }
                    elseif ($levels.Count -gt 2 -and $lowerText -match 'soon|today|important|problem|error|failed') {
                        $selectedIndex = $levels.Count - 2
                    }

                    $levelKeys = @($levels | ForEach-Object { [string] ([array]::IndexOf($levels, $_)) })
                    $legend = [ordered] @{}
                    for ($index = 0; $index -lt $levels.Count; $index++) {
                        $legend[[string] $index] = $levels[$index]
                    }

                    $answers[$name] = [pscustomobject] [ordered] @{
                        type          = 'score'
                        score         = [math]::Round([double] $selectedIndex, 2)
                        confidence    = if ($selectedIndex -eq 0) { 0.62 } else { 0.86 }
                        legend        = $legend
                        probabilities = New-JevProbabilityDistribution -Keys $levelKeys -SelectedIndex $selectedIndex
                    }
                }

                default {
                    throw "Unsupported Jev question type '$type'."
                }
            }
        }
    }

    return [pscustomobject] [ordered] @{
        model   = $Model
        answers = $answers
        usage   = [pscustomobject] [ordered] @{
            input_tokens  = 0
            output_tokens = 0
        }
    }
}
