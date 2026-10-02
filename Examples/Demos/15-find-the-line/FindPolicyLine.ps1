# Pick the policy line that best answers the question.
param(
    [string] $Path = "$PSScriptRoot/policy.txt",
    [string] $Question = 'When does a refund reach the customer?',
    [switch] $AllowNone
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$lines = @(Get-Content -LiteralPath $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($lines.Count -lt 2) {
    throw 'The policy needs at least two non-empty lines to search.'
}

# Choice answers use short labels, so keep a map back to each original policy line.
$criteria = [ordered]@{}
$lineByLabel = @{}
for ($index = 0; $index -lt $lines.Count; $index++) {
    $label = 'line{0:D2}' -f ($index + 1)
    $criteria[$label] = $lines[$index]
    $lineByLabel[$label] = $lines[$index]
}
if ($AllowNone) {
    $criteria['none'] = 'No line in this policy answers the question.'
}

# The question is the state; all policy lines are options in this single request.
$jevQuestion = New-JevQuestion -Name bestLine -Type Choice `
    -Instructions 'Which policy line best answers the question in the state?' `
    -Criteria $criteria

$decision = $Question | Invoke-Jev -Question $jevQuestion
$selected = [string] $decision.bestLine

# Print the exact source line, or hand off when Jev selects the optional none choice.
if ($selected -eq 'none' -and $AllowNone) {
    'ask a person'
}
elseif ($lineByLabel.ContainsKey($selected)) {
    $lineByLabel[$selected]
}
else {
    throw "Jev returned an unexpected policy line: '$selected'."
}
