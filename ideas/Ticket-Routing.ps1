#requires -Version 7.0

# Set TYPESAFE_API_KEY before running this live example.
Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

# ── Call-through functions ─────────────────────────────────────────
# Stand-ins for real routing logic — replace bodies with actual
# ticketing/Slack/PagerDuty calls when ready. Each returns the
# routing message so it can be attached to the decision object.

function Invoke-RetentionEscalation {
    param(
        [Parameter(Mandatory)] $Ticket
    )
    "[RETENTION ESCALATION] Ticket: $Ticket"
}

function Invoke-OnCallRoute {
    param(
        [Parameter(Mandatory)] $Ticket
    )
    "[ON-CALL] Paging on-call engineer for ticket: $Ticket"
}

function Invoke-QueueRoute {
    param(
        [Parameter(Mandatory)] [string] $Category,
        [Parameter(Mandatory)] $Ticket
    )
    "[QUEUE: $Category] Routed ticket: $Ticket"
}

function Invoke-HumanTriage {
    param(
        [Parameter(Mandatory)] $Ticket,
        [string] $Reason = 'Needs clarification'
    )
    "[HUMAN TRIAGE] Ticket: $Ticket — $Reason"    
}

# ── Core entry point ─────────────────────────────────────────────────
function Resolve-TicketRouting {
    param(
        [Parameter(Mandatory)] [string] $Ticket,
        [Parameter(Mandatory)] [string] $State,
        [ValidateRange(0, 1)]
        [double] $ConfidenceThreshold = 0.6
    )

    $questions = @(
        New-JevQuestion -Name urgency -Type Score `
            -Instructions 'How urgent is the operational response? Reserve Critical for an active production outage or widespread failure needing immediate on-call engineering.' `
            -Criteria @(
            'Can wait.'
            'Needs attention this week.'
            'Needs attention today, but no production outage.'
            'Active production outage or widespread failure requiring immediate on-call engineering.'
        )

        New-JevQuestion -Name category -Type Choice `
            -Instructions 'Which category is supported by the details in this ticket? Choose unclear when the message does not identify the issue well enough to route it.' `
            -Criteria @{
            billing         = 'Billing or invoicing issue'
            bug             = 'Product defect or error'
            feature_request = 'Request for new functionality'
            account_access  = 'Login, permissions, or access issue'
            unclear         = 'The message is too vague or mixes possible issues; ask for more details.'
        }

        New-JevQuestion -Name needsClarification -Type Noul `
            -Instructions 'Is there too little information to identify the actual issue and route this ticket?' `
            -Criteria @{ 
            true  = 'The issue is unclear or several different issues are plausible.'
            false = 'The issue is specific enough to route.' 
        }

        New-JevQuestion -Name churnRisk -Type Score `
            -Instructions 'How likely is this customer to churn?' `
            -Criteria @('Low', 'Medium', 'High')
    )

    $decision = Invoke-Jev -State $State -Question $questions

    $categoryConfidence = [double] $decision.answers.category.confidence
    $clarificationProbability = [double] $decision.answers.needsClarification.noul
    
    # Score is a numeric average of levels. Criteria start at index 0, so
    # churn level 2 is High and urgency level 3 is Critical.
    $highChurnProbability = [double] $decision.answers.churnRisk.probabilities.'2'
    $criticalProbability = [double] $decision.answers.urgency.probabilities.'3'

    if ($decision.category -eq 'unclear' -or
        $clarificationProbability -ge 0.5 -or
        $categoryConfidence -lt $ConfidenceThreshold) {
        $routingResult = Invoke-HumanTriage -Ticket $Ticket -Reason 'Issue needs clarification before routing'
    }
    elseif ($criticalProbability -ge 0.5) {
        $routingResult = Invoke-OnCallRoute -Ticket $Ticket
    }
    elseif ($highChurnProbability -ge 0.5) {
        $routingResult = Invoke-RetentionEscalation -Ticket $Ticket
    }
    else {
        $routingResult = Invoke-QueueRoute -Category $decision.category -Ticket $Ticket
    }

    $decision | Add-Member -NotePropertyName Ticket -NotePropertyValue $Ticket -Force
    $decision | Add-Member -NotePropertyName CategoryConfidence -NotePropertyValue $categoryConfidence -Force
    $decision | Add-Member -NotePropertyName ClarificationProbability -NotePropertyValue $clarificationProbability -Force
    $decision | Add-Member -NotePropertyName HighChurnProbability -NotePropertyValue $highChurnProbability -Force
    $decision | Add-Member -NotePropertyName CriticalProbability -NotePropertyValue $criticalProbability -Force
    $decision | Add-Member -NotePropertyName RoutingResult -NotePropertyValue $routingResult -Force

    return $decision
}

# ── Usage ────────────────────────────────────────────────────────────
# $ticketState = @'
# Customer: enterprise tier, 3yr tenure, $80k ACV
# Message: "This is the third time billing has charged us wrong.
# If this isn't fixed today I'm escalating to our exec sponsor."
# Recent tickets: 2 billing disputes in last 30 days
# '@

# $result = Resolve-TicketRouting -Ticket 'TICKET-4821' -State $ticketState
# $result

# Target routes illustrate the policy; model judgments can vary between runs.
$testTickets = @(
    @{
        Ticket   = 'TICKET-1001'
        State    = @'
Customer: enterprise tier, 3yr tenure, $80k ACV
Message: "This is the third time billing has charged us wrong.
If this isn't fixed today I'm escalating to our exec sponsor."
Recent tickets: 2 billing disputes in last 30 days
'@
        Expected = 'RetentionEscalation (high churn probability)'
    }
    @{
        Ticket   = 'TICKET-1002'
        State    = @'
Customer: mid-market, 6mo tenure.
Message: "Production is completely down, our checkout page returns a 500
error for every customer. We are losing sales right now."
Severity: all users affected, no workaround.
'@
        Expected = 'OnCallRoute (critical urgency probability)'
    }
    @{
        Ticket   = 'TICKET-1003'
        State    = @'
Customer: small business, 1yr tenure.
Message: "Could you add a dark mode option to the dashboard? Not urgent,
just a nice-to-have for our team."
No prior tickets.
'@
        Expected = 'QueueRoute (category=feature_request, low urgency, low churn)'
    }
    @{
        Ticket   = 'TICKET-1004'
        State    = @'
Customer: unspecified tier.
Message: "hey it broke again i think, not sure, maybe billing? or login?
kind of confusing today"
No other details provided.
'@
        Expected = 'HumanTriage (issue needs clarification)'
    }
)

foreach ($t in $testTickets) {
    Write-Host "`n=== $($t.Ticket) — target: $($t.Expected) ===" -ForegroundColor Cyan
    $result = Resolve-TicketRouting -Ticket $t.Ticket -State $t.State
    $result
}
