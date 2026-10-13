Clear-Host
# Score each message on an ordered urgency scale and sort the worklist.

$messages = Get-Content (Join-Path $PSScriptRoot 'messages.txt')

$messages | ForEach-Object {
    $message = $_
    $urgency = $message | Get-JevScore 'How urgent is this message?' `
        'Can wait' 'Needs attention soon' 'Needs attention now'

    [pscustomobject]@{
        Urgency = $urgency
        Message = $message
    }
} | Sort-Object Urgency -Descending | Format-Table -Wrap
