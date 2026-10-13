Clear-Host
# Judge each message independently, then return the three most urgent ones.

$messages = Get-Content (Join-Path $PSScriptRoot 'messages.txt')

$messages | Get-JevRanking 'Which message most needs attention today?' -Top 3
