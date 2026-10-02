. "$PSScriptRoot/Invoke-JevChoice.ps1"

$label = Get-Content "$PSScriptRoot/ticket.txt" -Raw |
    Invoke-JevChoice 'Which team owns this request?' billing shipping account other -Threshold 0.8

# $label = 'I was charged twice for my monthly subscription. Please refund the duplicate charge.' |
# Invoke-JevChoice 'Which team owns this request?' billing shipping account other -Threshold 0.8

switch ($label) {
    'billing' { 'queue=payments' }
    'shipping' { 'queue=logistics' }
    'account' { 'queue=identity' }
    'other' { 'queue=triage' }
    'not_sure' { 'triage' }
    default { throw "Unknown label: $label" }
}
