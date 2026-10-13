Clear-Host
# Apply several independent labels; a message may receive more than one tag.

$messages = Get-Content (Join-Path $PSScriptRoot 'messages.txt')

$tags = [ordered]@{
    billing      = 'A charge, invoice, payment, or refund issue.'
    service_down = 'A service outage is preventing people from using the product.'
    time_sensitive = 'The message describes a deadline or an immediate time pressure.'
}

$messages |
    Add-JevTag $tags -Threshold 0.75 |
    Select-Object State, Tags |
    Format-Table -Wrap
