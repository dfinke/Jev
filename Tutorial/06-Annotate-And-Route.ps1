Clear-Host
# Add a team answer to each message, then map that label to a queue.

$messages = Get-Content (Join-Path $PSScriptRoot 'messages.txt')

$team = New-JevQuestion -Name team -Type Choice `
    -Instructions 'Which team should handle this message?' `
    -Criteria @{
        billing = 'A charge, invoice, payment, or refund issue.'
        support = 'A product feature or service is broken.'
        sales   = 'A product, shipping, or plan question.'
        other   = 'The message does not fit the other categories.'
    }

$messages |
    Add-JevAnnotation -Question $team |
    ForEach-Object {
        $queue = switch ($_.team) {
            billing { 'Payments' }
            support { 'Product support' }
            sales   { 'Sales' }
            default { 'General triage' }
        }

        [pscustomobject]@{
            Message = $_.State
            Team    = $_.team
            Queue   = $queue
        }
    } |
    Format-Table -Wrap
