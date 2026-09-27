#requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates the Speculative Fan-Out pattern for customer support routing.

.DESCRIPTION
    Instead of making multiple sequential roundtrips to Jev, all questions
    (department choice, churn probability, bug severity, refund eligibility)
    are sent in a single request. PowerShell branches execution based on the
    primary choice and consumes the relevant speculative answers.

.EXAMPLE
    .\SpeculativeCustomerRouter.ps1
#>
[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$tickets = @(
    [pscustomobject]@{
        id      = 'TCK-101'
        message = 'Checkout is throwing a 500 error when applying coupon code SAVE20. We are losing transactions!'
    }
    [pscustomobject]@{
        id      = 'TCK-102'
        message = 'My credit card was charged twice for the annual renewal. Please issue a refund ASAP or I will cancel.'
    }
    [pscustomobject]@{
        id      = 'TCK-103'
        message = 'Can you send me the SOC2 Type II compliance report for our security audit?'
    }
)

# Bundle questions into a single Speculative Fan-Out set
$questions = @(
    # Primary routing question
    New-JevChoiceQuestion   -Name 'department' 
                            -Instructions 'Which department should handle this customer inquiry?' 
                            -Choices @{
                                technical = 'Software bugs, 500 errors, API failures, or integration issues'
                                billing   = 'Double charges, invoice errors, renewals, and refunds'
                                security  = 'Compliance, SOC2 audits, privacy requests, and certifications'
                            } -AllowOther

    # Global signal
    New-JevYesNoQuestion    -Name 'is_churn_risk' 
                            -Question 'Is the customer threatening to cancel or stop using the product?' `
                            -TrueCriteria 'Customer mentions canceling, demanding refund on threat of leaving, or switching' `
                            -FalseCriteria 'Customer is requesting assistance normally'

    # Speculative question for technical branch
    New-JevScoreQuestion    -Name 'bug_severity' 
                            -Instructions 'How severe is the technical defect described in `message`?' 
                            -Levels @(
                                'Minor - cosmetic or low priority'
                                'Moderate - workaround available'
                                'Critical - revenue loss or widespread blockage'
                            )

    # Speculative question for billing branch
    New-JevYesNoQuestion    -Name 'refund_requested' 
                            -Question 'Does the customer explicitly ask for money back?' `
                            -TrueCriteria 'Customer requests a refund or reimbursement' `
                            -FalseCriteria 'Inquiry about pricing, upgrades, or invoice explanation'
)

Write-Host "Evaluating $($tickets.Count) tickets using Speculative Fan-Out in one Jev pass per ticket...`n" -ForegroundColor Cyan

foreach ($ticket in $tickets) {
    Write-Host "--- Processing Ticket $($ticket.id) ---" -ForegroundColor Yellow
    Write-Host "Message: $($ticket.message)"

    # Evaluates all questions in one request
    $decision = Invoke-Jev -State $ticket -Question $questions -MockOnMissingKey

    $deptChoice = $decision.department
    $churnProb = $decision.is_churn_risk
    Write-Host "Routed To: $deptChoice (Churn Risk: $([math]::Round($churnProb, 2)))" -ForegroundColor Green

    # Branch in code and consume branch-specific speculative answers
    switch ($deptChoice) {
        'technical' {
            $severity = $decision.bug_severity
            Write-Host "  -> Technical Queue: Severity score = $severity"
            if ($severity -ge 1.5 -or $churnProb -ge 0.7) {
                Write-Host "  [!] Flagged for On-Call Engineer Dispatch" -ForegroundColor Red
            }
        }
        'billing' {
            $wantsRefund = $decision.refund_requested
            Write-Host "  -> Billing Queue: Refund Requested = $(if ($wantsRefund -ge 0.8) {'Yes'} else {'No'})"
            if ($wantsRefund -ge 0.8) {
                Write-Host "  [!] Auto-generated Refund Approval Draft for Finance" -ForegroundColor Magenta
            }
        }
        'security' {
            Write-Host "  -> Security Compliance Queue: Dispatched to Security Portal Auto-Responder" -ForegroundColor Cyan
        }
        default {
            Write-Host "  -> General Queue for Human Review"
        }
    }
    Write-Host ""
}
