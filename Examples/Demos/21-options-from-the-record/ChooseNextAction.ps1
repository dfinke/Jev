# Ask Jev to choose from the actions available at each step.
param(
    [string] $Path = "$PSScriptRoot/steps.jsonl",
    [ValidateRange(0.0, 1.0)]
    [double] $Threshold = 0.8
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

foreach ($line in Get-Content -LiteralPath $Path) {
    $step = $line | ConvertFrom-Json
    $actionOptions = [ordered]@{}

    if ($step.actions -is [array]) {
        foreach ($action in $step.actions) {
            $actionOptions[[string] $action] = $null
        }
    }
    elseif ($null -ne $step.actions) {
        foreach ($property in $step.actions.PSObject.Properties) {
            $actionOptions[$property.Name] = $property.Value
        }
    }
    else {
        throw "Step '$($step.id)' has no actions."
    }

    if ($actionOptions.Count -lt 2 -or $actionOptions.Count -gt 255) {
        throw "Step '$($step.id)' must have between 2 and 255 actions."
    }

    $question = New-JevQuestion -Name nextAction -Type Choice `
        -Instructions 'Which of the available actions should happen next?' `
        -Criteria $actionOptions

    $decision = $step.state | Invoke-Jev -Question $question
    $suggestedAction = [string] $decision.nextAction

    if (-not $actionOptions.Contains($suggestedAction)) {
        $probability = $null
        $nextStep = 'ask a person'
    }
    else {
        # Use the selected action's probability to decide whether to trust the suggestion.
        $probability = [double] $decision.answers.nextAction.probabilities.($suggestedAction)
        $nextStep = if ($probability -ge $Threshold) { $suggestedAction } else { 'ask a person' }
    }

    [pscustomobject]@{
        Id              = $step.id
        SuggestedAction = $suggestedAction
        Probability     = if ($null -eq $probability) { $null } else { [math]::Round($probability, 2) }
        NextStep        = $nextStep
    }
}
