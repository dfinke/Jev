#requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates confidence-gated routing for actions with different risks.

.DESCRIPTION
    Jev classifies the requested action. PowerShell applies a different
    confidence threshold to each action and produces a suggested next step.
    This example does not read account data or perform any account action.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./ideas/Confidence-Gated-Routing/Invoke-ConfidenceGatedRouting.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

$requests = @(
    [pscustomobject]@{
        RequestId = 'REQ-301'
        Request   = 'What is the current balance in my checking account?'
    }
    [pscustomobject]@{
        RequestId = 'REQ-302'
        Request   = 'Tag this case as billing and send it to the billing support queue.'
    }
    [pscustomobject]@{
        RequestId = 'REQ-303'
        Request   = 'Transfer 500 dollars from checking to my saved rent recipient today.'
    }
    [pscustomobject]@{
        RequestId = 'REQ-304'
        Request   = 'Permanently close my account and delete its records.'
    }
    [pscustomobject]@{
        RequestId = 'REQ-305'
        Request   = 'Something looks off with my last payment. Can you help?'
    }
)

$intentQuestion = New-JevQuestion -Name intent -Type Choice `
    -Instructions 'Which next action is the customer asking for?' `
    -Criteria @{
    show_balance         = 'Read account balance or show other information without changing anything.'
    tag_and_route_ticket = 'Label a support case and send it to a human support queue.'
    approve_transfer     = 'Initiate or approve a transfer that moves money between accounts or recipients.'
    delete_account       = 'Permanently close an account or delete account records.'
    unclear              = 'The requested action is too vague to identify safely.'
}

$results = foreach ($request in $requests) {
    $decision = Invoke-Jev -State $request -Question $intentQuestion
    $intent = [string] $decision.intent
    $confidence = [double] $decision.answers.intent.confidence

    # These illustrative thresholds rise with the cost of a mistaken action.
    $threshold = $null
    $nextStep = $null
    $reason = $null

    switch ($intent) {
        'show_balance' {
            $threshold = 0.50
            if ($confidence -ge $threshold) {
                $nextStep = 'Show balance (read-only)'
                $reason = 'Read-only information has low impact if the route is mistaken.'
            }
            else {
                $nextStep = 'Ask a person to review'
                $reason = 'Confidence is below the read-only action threshold.'
            }
        }
        'tag_and_route_ticket' {
            $threshold = 0.65
            if ($confidence -ge $threshold) {
                $nextStep = 'Tag and route to support'
                $reason = 'A support person reviews the case after routing.'
            }
            else {
                $nextStep = 'Ask a person to review'
                $reason = 'Confidence is below the support-routing threshold.'
            }
        }
        'approve_transfer' {
            $threshold = 0.85
            if ($confidence -ge $threshold) {
                $nextStep = 'Ask customer to confirm transfer'
                $reason = 'High confidence can prepare the next step, but money movement still needs confirmation.'
            }
            else {
                $nextStep = 'Ask a person to review'
                $reason = 'Money movement uses a higher confidence threshold.'
            }
        }
        'delete_account' {
            $threshold = 'Manual'
            $nextStep = 'Require manual review'
            $reason = 'Account deletion is irreversible, so confidence alone cannot authorize it.'
        }
        default {
            $threshold = 'Manual'
            $nextStep = 'Ask a clarifying question'
            $reason = 'The requested action is unclear or outside the defined choices.'
        }
    }

    [pscustomobject]@{
        RequestId  = $decision.RequestId
        Intent     = $intent
        Confidence = [math]::Round($confidence, 2)
        Threshold  = $threshold
        NextStep   = $nextStep
        Reason     = $reason
        Request    = $decision.Request
    }
}

# Routing plan
$results | Format-Table RequestId, Intent, Confidence, Threshold, NextStep -AutoSize -Wrap
