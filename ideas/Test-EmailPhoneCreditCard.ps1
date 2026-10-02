import-module Jev.psd1 -Force

<#
Visa: 4111111111111111
Mastercard: 5105105105105100
Amex: 378282246310005
Discover: 6011111111111117
#>
$states = @(
    "order shipped. refund my card"
    "order shipped. refund my card 6011111111111117"
    "order #A-1043 hasn't shipped. reach me at dana.ruiz@northwind.co or (415) 555-0147"
    "order #A-1043 hasn't shipped. reach me at dana.ruiz@northwind.co or (415) 555-0147. card 378282246310005"
)

$hasEmail = New-JevYesNoQuestion -Name hasEmail `
    -Question 'Does this include an email?' `
    -TrueCriteria 'The message includes an email address.' `
    -FalseCriteria 'The message does not include an email address.'

$hasPhone = New-JevYesNoQuestion -Name hasPhone `
    -Question 'Does this include a phone number?' `
    -TrueCriteria 'The message includes a phone number.' `
    -FalseCriteria 'The message does not include a phone number.'

$hasCreditCard = New-JevYesNoQuestion -Name hasCreditCard `
    -Question 'Does this include a credit card number?' `
    -TrueCriteria 'The message includes a credit card number.' `
    -FalseCriteria 'The message does not include a credit card number.'

$states | Invoke-Jev -Question $hasEmail, $hasPhone, $hasCreditCard | ForEach-Object {
    $threshold = 0.8
    [pscustomobject]@{
        State         = $_.State
        HasEmail      = $_.hasEmail -gt $threshold ? 'Yes' : 'No'
        HasPhone      = $_.hasPhone -gt $threshold ? 'Yes' : 'No'
        HasCreditCard = $_.hasCreditCard -gt $threshold ? 'Yes' : 'No'
    }
} | Format-Table -AutoSize