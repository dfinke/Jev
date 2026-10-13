Clear-Host
# Classify one ticket into the queue that should own it.

$state = @'
Export to CSV has been broken since Friday.
It works in Chrome, but half our team is on Safari and they can't pull reports at all.
We have a board meeting Thursday.
'@

$question = New-JevQuestion -Name department -Type Choice `
    -Instructions 'Which queue should own this ticket?' `
    -Criteria @{
    bug_triage        = 'A defect in a specific feature, reproducible, goes into the backlog'
    incident_response = 'A live breakage affecting multiple users right now, needs a responder today'
    customer_success  = 'The account needs managing, not the code'
}

$state | Invoke-Jev -Question $question | Select-Object department, State
