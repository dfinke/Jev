#requires -Version 7.0

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$feedback = [pscustomobject] @{
    message = 'The customer is blocked by an outage and may cancel.'
}

$questions = @(
    New-JevQuestion `
        -Name churn `
        -Type Noul `
        -Instructions 'Is this an active churn threat?'

    New-JevQuestion `
        -Name urgency `
        -Type Score `
        -Instructions 'How urgent is this?' `
        -Criteria @('Can wait', 'This week', 'Today')
)

Invoke-Jev -InputObject $feedback -Question $questions -Mock
