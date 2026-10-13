Clear-Host
# Compare the inbox messages together and return the best match.

$messages = Get-Content (Join-Path $PSScriptRoot 'messages.txt')

$messages | Find-Jev 'Which message most clearly reports a current service outage?'
