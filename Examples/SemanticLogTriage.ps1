#requires -Version 7.0

<##
.SYNOPSIS
    Classifies a few log lines with typed Jev questions.

.DESCRIPTION
    Each log line is evaluated with the same Noul and Choice questions.
    Jev returns typed answers; PowerShell turns them into sortable properties.
#>

[CmdletBinding()]
param(
    [string[]] $LogLine = @(
        'INFO web service started successfully on port 8080.'
        'WARN DNS lookup timed out while connecting to api.internal.'
        'ERROR invalid JSON in the deployment configuration.'
        'ALERT unauthorized login followed by a privilege escalation attempt.'
    )
)

# Set TYPESAFE_API_KEY before running this example.
Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$questions = @(
    New-JevQuestion `
        -Name critical_security_risk `
        -Type Noul `
        -Instructions 'Is this log line evidence of a critical security risk or attack?' `
        -Criteria @{ `
            true  = 'A breach, unauthorized access, credential attack, or privilege escalation.'
            false = 'A normal operational message or a non-security application failure.'
        }

    New-JevQuestion `
        -Name root_cause `
        -Type Choice `
        -Instructions 'What is the most likely root-cause category for this log line?' `
        -Criteria @{ `
            auth    = 'Authentication, credentials, identity, authorization, or access failure.'
            network = 'Network, DNS, connection, socket, timeout, or transport failure.'
            syntax  = 'Syntax, parsing, malformed configuration, or invalid format failure.'
            unknown = 'No clear root-cause category is supported by the line.'
        }
)

$results = foreach ($line in $LogLine) {
    $response = Invoke-Jev `
        -InputObject @{ log_line = $line } `
        -Question $questions

    $security = $response.answers.critical_security_risk
    $cause = $response.answers.root_cause
    $criticalRisk = [math]::Round([double] $security.noul, 3)
    $emoji = if ($criticalRisk -ge 0.8) {
        '🔴'
    }
    elseif ($criticalRisk -ge 0.5) {
        '🟠'
    }
    else {
        '🟢'
    }

    [pscustomobject]@{
        EmojiIndicator     = $emoji
        LogLine            = $line
        CriticalRisk       = $criticalRisk
        RootCause          = [string] $cause.choice
        RootCauseConfidence = [math]::Round([double] $cause.confidence, 3)
    }
}

$results |
    Sort-Object CriticalRisk -Descending |
    Format-Table EmojiIndicator, CriticalRisk, RootCause, RootCauseConfidence, LogLine -Wrap -AutoSize
