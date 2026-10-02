# Ask Jev whether the customer wants a refund, then print the matching route.
param([string] $Path = "$PSScriptRoot/message.txt")

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$question = New-JevQuestion -Name refund -Type Noul `
    -Instructions 'Does the customer ask for money back?'

$decision = Get-Content -LiteralPath $Path -Raw |
    Invoke-Jev -Question $question

if ($decision.refund -ge 0.5) {
    'refunds'
} else {
    'normal'
}
