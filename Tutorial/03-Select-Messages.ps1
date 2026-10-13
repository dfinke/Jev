Clear-Host
# Keep the original messages that Jev judges as needing a reply.

$messages = Get-Content (Join-Path $PSScriptRoot 'messages.txt')

$messages | Select-Jev 'Does this message need a reply?'
