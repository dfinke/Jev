#requires -Version 7.0

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$feedback = [pscustomobject] @{
    message = 'The customer is blocked by an outage and may cancel.'
}

$questions = @(
    New-JevQuestion `
        -Name churn `
        -Type Noul `
        -Instructions 'Is this an active churn threat?' `
        -Criteria @{ `
            true = 'The customer may leave or cancel.'
            false = 'The customer is stable and engaged.'
        }

    New-JevQuestion `
        -Name route `
        -Type Choice `
        -Instructions 'Which team should handle this?' `
        -Criteria @{ `
            support = 'The issue needs technical support.'
            sales = 'The issue concerns pricing or renewal.'
        }

    New-JevQuestion `
        -Name urgency `
        -Type Score `
        -Instructions 'How urgent is this?' `
        -Criteria @('Can wait', 'This week', 'Today')
)

Invoke-Jev -InputObject $feedback -Question $questions -Mock
