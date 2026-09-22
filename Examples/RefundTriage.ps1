#requires -Version 7.0

# Inspired by TypeSafe's primitives example:
# https://docs.typesafe.ai/primitives
# Set TYPESAFE_API_KEY before running this example.

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$state = [ordered]@{
    ticket_message = 'My flight was cancelled. Can I get a refund?'
    refund_policy  = 'Cancelled flights are eligible for a full refund.'
}

$questions = @(
    New-JevQuestion `
        -Name refund_requested `
        -Type Noul `
        -Instructions 'Does `ticket_message` request a refund?'

    New-JevQuestion `
        -Name request_type `
        -Type Choice `
        -Instructions 'What is the main request in `ticket_message`?' `
        -Criteria @{ `
            refund      = 'The customer wants money returned.'
            rebooking   = 'The customer wants a replacement flight.'
            information = 'The customer is asking for information only.'
        }

    New-JevQuestion `
        -Name frustration `
        -Type Score `
        -Instructions 'How frustrated does the customer appear in `ticket_message`?' `
        -Criteria @(
            'Calm and neutral.'
            'Concerned but civil.'
            'Very angry or using strong language.'
        )
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
