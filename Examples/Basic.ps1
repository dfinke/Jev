#requires -Version 7.0

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$feedback = [pscustomobject] @{
    message = 'The customer is blocked by an outage and may cancel.'
}

$questions = @(
    New-JevQuestion `
        -Name churn `
        -Type Noul `
        -Prompt 'Is this an active churn threat?'

    New-JevQuestion `
        -Name urgency `
        -Type Score `
        -Prompt 'How urgent is this?' `
        -Level @('Can wait', 'This week', 'Today')
)

Invoke-Jev -InputObject $feedback -Question $questions -Mock
