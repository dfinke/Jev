#requires -Version 7.0

# Set TYPESAFE_API_KEY before running this example. Each state makes one Jev request.
Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

# This example pages for widespread checkout failure and leaves uncertain cases
# for review. The criteria express the policy; Jev assesses each incident.
$question = New-JevYesNoQuestion `
    -Name pageOnCall `
    -Question 'Based on customer checkout impact, should the on-call engineer be paged now?' `
    -TrueCriteria 'Checkout is unavailable or a substantial share of customers cannot complete purchases.' `
    -FalseCriteria 'Customers can complete purchases normally; isolated card declines and unrelated dashboards do not count.'

# Compare clear outages, normal operation, and cases near the policy boundary.
$states = @(
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

# These cutoffs are illustrative policy choices, not Jev defaults. The Noul
# value is the probability of "yes"; a middle value calls for review.
$results = foreach ($issue in $states) {
    $decision = Invoke-Jev -State $issue -Question $question
    $probabilityOfPage = [double] $decision.answers.pageOnCall.noul

    $action = if ($probabilityOfPage -ge 0.8) {
        'Page'
    }
    elseif ($probabilityOfPage -le 0.2) {
        'Do not page'
    }
    else {
        'Review'
    }

    [pscustomobject]@{
        Action            = $action
        ProbabilityOfPage = [math]::Round($probabilityOfPage, 2)
        Issue             = $issue
    }
}

$results | Format-Table -AutoSize -Wrap
