# Ask Jev three focused questions, then apply a small deterministic triage policy.
param([string] $Path = "$PSScriptRoot/tickets.csv")

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$credentialQuestion = New-JevYesNoQuestion -Name credentialRequest `
    -Question 'Does the customer ask the support agent to provide or reveal a password, login code, security code, token, or other credential?' `
    -TrueCriteria 'The customer asks support to provide or reveal a credential.' `
    -FalseCriteria 'The customer does not ask support to provide or reveal a credential.'

$queueQuestion = New-JevQuestion -Name queue -Type Choice `
    -Instructions 'Which support queue owns this request?' `
    -Criteria @{
        billing  = 'Charges, refunds, invoices, or payments.'
        shipping = 'Orders, delivery, tracking, or saved delivery addresses.'
        account  = 'Sign-in, account access, profiles, or account settings.'
        other    = 'Anything outside billing, shipping, and account support.'
    }

$urgencyQuestion = New-JevQuestion -Name urgency -Type Score `
    -Instructions 'How soon does this request need action?' `
    -Criteria @(
        'Routine: normal handling is enough.'
        'Soon: delay could cause a concrete customer problem.'
        'Immediate: delay is already causing serious harm or loss.'
    )

$questions = @($credentialQuestion, $queueQuestion, $urgencyQuestion)
$credentialYesThreshold = 0.8
$credentialNoThreshold = 0.2
$queueThreshold = 0.8
$urgentThreshold = 1.0

foreach ($ticket in Import-Csv -LiteralPath $Path) {
    # Send only the message body; keep ticket metadata local to PowerShell.
    $decision = $ticket.body | Invoke-Jev -Question $questions

    $credentialProbability = if ($null -eq $decision.credentialRequest) {
        $null
    }
    else {
        [double] $decision.credentialRequest
    }

    $credentialRequest = if ($null -eq $credentialProbability) {
        $null
    }
    elseif ($credentialProbability -ge $credentialYesThreshold) {
        $true
    }
    elseif ($credentialProbability -le $credentialNoThreshold) {
        $false
    }
    else {
        $null
    }

    $queueLabel = [string] $decision.queue
    $queueProbability = if ([string]::IsNullOrWhiteSpace($queueLabel)) {
        $null
    }
    else {
        [double] $decision.answers.queue.probabilities.($queueLabel)
    }
    $queue = if ($null -eq $queueProbability -or $queueProbability -lt $queueThreshold) {
        $null
    }
    else {
        $queueLabel
    }

    $urgency = if ($null -eq $decision.urgency) {
        $null
    }
    else {
        [double] $decision.urgency
    }

    if ($null -eq $credentialRequest -or $null -eq $queue -or $null -eq $urgency) {
        $action = 'review'
        $reason = 'unsure'
    }
    elseif ($credentialRequest) {
        $action = 'block'
        $reason = 'credential_request'
    }
    elseif ($queue -eq 'other') {
        $action = 'review'
        $reason = 'out_of_scope'
    }
    elseif ($urgency -ge $urgentThreshold) {
        $action = 'review'
        $reason = 'urgent'
    }
    else {
        $action = 'draft'
        $reason = 'routine'
    }

    [pscustomobject]@{
        Id                    = $ticket.id
        Subject               = $ticket.subject
        CredentialRequest     = if ($null -eq $credentialRequest) { 'unsure' } elseif ($credentialRequest) { 'yes' } else { 'no' }
        CredentialProbability = if ($null -eq $credentialProbability) { $null } else { [math]::Round($credentialProbability, 2) }
        Queue                 = if ($null -eq $queue) { 'unsure' } else { $queue }
        QueueProbability      = if ($null -eq $queueProbability) { $null } else { [math]::Round($queueProbability, 2) }
        Urgency               = if ($null -eq $urgency) { $null } else { [math]::Round($urgency, 2) }
        Action                = $action
        Reason                = $reason
    }
}
