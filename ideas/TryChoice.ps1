import-module Jev.psd1 -Force

$incidents = @(
    'Checkout is returning HTTP 503 errors, and no customers can place orders.'
    'Checkout is slower than usual, but customers are still completing purchases successfully.'
    'The payment provider is declining every transaction. Customers cannot complete purchases.'
    'The payment provider is degraded, but the backup processor is handling all transactions.'
    'About 30 percent of checkout attempts are failing with a payment timeout.'
    'The internal reporting dashboard is down. Checkout and customer purchases are working normally.'
    'The orders database is unavailable, so checkout cannot save or complete purchases.'
    "A single customer’s payment failed because their card was declined. Other purchases are succeeding."
    'Customers are unable to buy anything after the latest deployment. The failure has lasted 12 minutes.'
    'A scheduled maintenance check is running. No checkout errors or failed purchases have been reported.'
)

$categoryQuestion = New-JevQuestion -Name category -Type Choice `
    -Instructions 'Which category best describes this incident?' `
    -Criteria @{
    billing            = 'A charge, invoice, refund, or payment problem.'
    account_access     = 'A sign-in, password, or account access problem.'
    bug                = 'A product feature is failing or behaving incorrectly.'
    no_customer_impact = 'There is no current customer impact, such as routine maintenance or a working backup.'
    unclear            = 'There is not enough information to classify the incident.'
}

$pageQuestion = New-JevYesNoQuestion -Name pageOnCall `
    -Question 'Should the on-call engineer be paged now?' `
    -TrueCriteria 'Customers cannot complete purchases or a critical service is unavailable.' `
    -FalseCriteria 'Purchases are working normally or there is no current customer impact.'

$incidents |
Invoke-Jev -Question @($categoryQuestion, $pageQuestion) |
Select-Object State, category, @{
    Name       = 'Action'
    Expression = {
        if ($_.pageOnCall -ge 0.8) { 'page' }
        elseif ($_.pageOnCall -le 0.2) { 'do not page' }
        else { 'review' }
    }
} | Format-Table -AutoSize