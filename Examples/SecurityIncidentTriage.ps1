#requires -Version 7.0

# Inspired by TypeSafe's Security Incidents workflow:
# https://evals.typesafe.ai/security_incidents
# Set TYPESAFE_API_KEY before running this example.

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$state = [ordered]@{
    alert = 'A PowerShell process read LSASS memory using comsvcs.dll on a production server.'
    asset = [ordered]@{
        environment = 'production'
        tier        = 'critical'
        owner       = 'platform operations'
    }
    open_tickets = @(
        'INC-1042: investigate unusual PowerShell activity on the production server'
    )
    registered_devices = @(
        'The owner normally uses a managed Windows laptop from the corporate network.'
    )
    scheduled_maintenance = @(
        'No maintenance window is scheduled.'
    )
    standing_authorizations = @(
        'Platform operations may run approved diagnostics during an incident.'
    )
}

$questions = @(
    New-JevQuestion `
        -Name unauthorized_activity `
        -Type Noul `
        -Instructions 'Does `alert` describe unauthorized activity given `standing_authorizations` and `scheduled_maintenance`?' `
        -Criteria @{ `
            true  = 'The activity is not explained by an authorization or maintenance window.'
            false = 'The activity is explained by an approved authorization or maintenance window.'
        }

    New-JevQuestion `
        -Name evidence_strength `
        -Type Score `
        -Instructions 'How strong is the evidence that the activity in `alert` is harmful, given the asset and incident records?' `
        -Criteria @(
            'Weak: an unusual event with a plausible benign explanation.'
            'Moderate: suspicious activity with incomplete supporting evidence.'
            'Strong: a high impact asset and a clear malicious technique.'
        )

    New-JevQuestion `
        -Name response `
        -Type Choice `
        -Instructions 'What immediate response best fits this alert and the available records?' `
        -Criteria @{ `
            notify_user    = 'Notify the asset owner and continue monitoring.'
            escalate_tier2 = 'Queue the alert for a security analyst.'
            kill_process   = 'Stop the suspicious process while preserving the account.'
            disable_account = 'Disable the suspected account because identity misuse is likely.'
            escalate_urgent = 'Escalate urgently because the production impact is severe or expanding.'
        }
)

$response = Invoke-Jev -InputObject $state -Question $questions

'Input state:'
$state | ConvertTo-Json -Depth 10

'Raw Jev response:'
$response | ConvertTo-Json -Depth 10

$summary = foreach ($answerProperty in $response.answers.PSObject.Properties) {
    $answer = $answerProperty.Value
    $decision = $null
    $probability = $null
    $confidence = $null

    switch ($answer.type.ToLowerInvariant()) {
        'noul' {
            $decision = if ($answer.noul -ge 0.5) { 'True' } else { 'False' }
            $probability = [math]::Round($answer.noul, 3)
        }
        'choice' {
            $decision = $answer.choice
            $confidence = [math]::Round($answer.confidence, 3)
        }
        'score' {
            $decision = $answer.score
            $confidence = [math]::Round($answer.confidence, 3)
        }
    }

    [pscustomobject]@{
        Question    = $answerProperty.Name
        Type        = $answer.type
        Decision    = $decision
        Probability = $probability
        Confidence  = $confidence
    }
}

'Readable decisions:'
$summary | Format-Table -AutoSize -Wrap
