#requires -Version 7.0

# Set TYPESAFE_API_KEY before running this example.

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

$result = Invoke-Jev -InputObject $feedback -Question $questions

# Keep the raw Jev response in $result. This view makes the message and the
# corresponding decisions easy to read together.
$answerEntries = if ($result.answers -is [System.Collections.IDictionary]) {
    @($result.answers.GetEnumerator())
}
else {
    @($result.answers.PSObject.Properties | ForEach-Object {
        [pscustomobject] @{
            Key   = $_.Name
            Value = $_.Value
        }
    })
}

$summary = foreach ($answerEntry in $answerEntries) {
    $answer = $answerEntry.Value

    switch ($answer.type.ToLowerInvariant()) {
        'noul' {
            [pscustomobject] @{
                Message            = $feedback.message
                Question           = $answerEntry.Key
                Type               = $answer.type
                Result             = if ($answer.noul -ge 0.5) { 'True' } else { 'False' }
                ProbabilityOfTrue  = [math]::Round($answer.noul, 3)
            }
        }
        'choice' {
            [pscustomobject] @{
                Message    = $feedback.message
                Question   = $answerEntry.Key
                Type       = $answer.type
                Result     = $answer.choice
                Confidence = [math]::Round($answer.confidence, 3)
            }
        }
        'score' {
            [pscustomobject] @{
                Message    = $feedback.message
                Question   = $answerEntry.Key
                Type       = $answer.type
                Result     = $answer.score
                Confidence = [math]::Round($answer.confidence, 3)
            }
        }
    }
}

'Raw Jev response:'
$result | ConvertTo-Json -Depth 10

'Readable summary:'
$summary | Format-Table -AutoSize -Wrap
