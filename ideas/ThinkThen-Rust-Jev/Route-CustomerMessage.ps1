. "$PSScriptRoot/Test-Jev.ps1"

function Test-MoneyBackRequest($Message) {
    $Message | Test-Jev 'Does the customer ask for money back?'
}

if (Test-MoneyBackRequest (Get-Content "$PSScriptRoot/question.txt")) {
    'refunds'
} else {
    'normal'
}