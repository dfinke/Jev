#requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates a Jev-first cascade for routine and complex support tickets.

.DESCRIPTION
    Jev classifies each ticket and assesses whether it is high stakes. PowerShell
    handles known, low-risk cases from the supplied CSV, routes product issues
    to a specialist, and escalates uncertain or high-risk cases. No external
    ticketing, order, or payment systems are called.

.PARAMETER InputPath
    CSV path. Defaults to support-tickets.csv beside this script.

.PARAMETER OutputPath
    Results CSV path. Defaults to output/cascade-routing-results.csv beside
    this script.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./ideas/Cascade-Ticket-Routing/Invoke-CascadeTicketRouting.ps1
#>
[CmdletBinding()]
param(
    [string] $InputPath = (Join-Path $PSScriptRoot 'support-tickets.csv'),

    [string] $OutputPath = (Join-Path $PSScriptRoot 'output/cascade-routing-results.csv'),

    [ValidateRange(0.0, 1.0)]
    [double] $HighStakesThreshold = 0.75
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Input CSV not found: $InputPath"
}

# Confidence bars are example policy choices. More consequential routes use
# higher bars; high-stakes cases are escalated separately, whatever the intent.
$intentConfidenceThresholds = @{
    order_status  = 0.50 # Read-only lookup from the supplied sample facts.
    refund_policy = 0.70 # Explain a policy match; never issue a refund.
    product_issue = 0.60 # Route to a support specialist for review.
}

$questions = @(
    New-JevQuestion -Name intent -Type Choice `
        -Instructions 'What is the customer mainly asking for?' `
        -Criteria @{
            order_status  = 'A lookup of an order shipping or delivery status.'
            refund_policy = 'An explanation of refund eligibility or a refund request.'
            product_issue = 'Help with a product error, defect, or integration problem.'
            unclear       = 'The request is too vague or does not fit the other choices.'
        }

    New-JevYesNoQuestion -Name highStakes `
        -Question 'Does this need immediate human attention because of serious financial harm, suspected unauthorized activity, or a customer-impacting outage?' `
        -TrueCriteria 'There is suspected fraud or unauthorized activity, serious immediate financial harm, or a broad outage blocking customers.' `
        -FalseCriteria 'The request is routine, low impact, or has a safe workaround.'
)

$tickets = @(Import-Csv -LiteralPath $InputPath)
if ($tickets.Count -eq 0) {
    throw "Input CSV contains no tickets: $InputPath"
}

$results = foreach ($ticket in $tickets) {
    # One ticket state; both bounded questions travel in this single Jev call.
    $decision = $ticket | Invoke-Jev -Question $questions
    $intent = [string] $decision.intent
    $intentConfidence = [double] $decision.answers.intent.confidence
    $highStakesProbability = [double] $decision.highStakes

    $threshold = $intentConfidenceThresholds[$intent]
    $handling = $null
    $outcome = $null

    if ($highStakesProbability -ge $HighStakesThreshold) {
        $handling = 'Escalate to human review'
        $outcome = 'High-stakes signal is above the escalation threshold.'
    }
    elseif ($intent -eq 'unclear') {
        $handling = 'Ask for clarification'
        $outcome = 'The request does not fit a supported routine path.'
    }
    elseif ($null -eq $threshold -or $intentConfidence -lt $threshold) {
        $handling = 'Escalate to human review'
        $outcome = 'Intent confidence is below the route threshold.'
    }
    else {
        switch ($intent) {
            'order_status' {
                if ([string]::IsNullOrWhiteSpace($decision.OrderStatus)) {
                    $handling = 'Ask for order details'
                    $outcome = 'The sample has no order status to look up.'
                }
                else {
                    $handling = 'Handled by PowerShell'
                    $outcome = "Order $($decision.OrderId) status: $($decision.OrderStatus)."
                }
            }
            'refund_policy' {
                if ($decision.DuplicateChargeConfirmed -eq 'true') {
                    $handling = 'Handled by PowerShell'
                    $outcome = 'Policy match: confirmed duplicate charges are eligible for refund review.'
                }
                else {
                    $handling = 'Route to billing specialist'
                    $outcome = 'The sample facts do not confirm a duplicate charge.'
                }
            }
            'product_issue' {
                $handling = 'Route to product support'
                $outcome = 'A support specialist should review the product issue.'
            }
        }
    }

    [pscustomobject]@{
        TicketId              = $decision.TicketId
        Intent                = $intent
        IntentConfidence      = [math]::Round($intentConfidence, 2)
        ConfidenceThreshold   = if ($null -eq $threshold) { '—' } else { $threshold }
        HighStakesProbability = [math]::Round($highStakesProbability, 2)
        Handling              = $handling
        Outcome               = $outcome
        Message               = $decision.Message
    }
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8

Write-Host "Cascade results for $($results.Count) tickets:" -ForegroundColor Cyan
$results | Format-Table TicketId, Intent, IntentConfidence, HighStakesProbability, Handling, Outcome -AutoSize -Wrap

Write-Host 'Tickets by destination:' -ForegroundColor Cyan
$results | Group-Object Handling | Select-Object @{ Name = 'Destination'; Expression = { $_.Name } }, Count | Format-Table -AutoSize
Write-Host "Full results written to: $OutputPath" -ForegroundColor Green
