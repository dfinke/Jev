Clear-Host
# Start with one state and one yes-or-no question.

$state = @'
Your support team was fantastic.
I still have to rebuild my saved filters every time I sign in.
Can you help me keep them?
'@

$question = 'Is the customer reporting an unresolved product problem?'

[pscustomobject]@{
    State     = $state
    NeedsHelp = $state | Test-Jev $question
} | Format-List
