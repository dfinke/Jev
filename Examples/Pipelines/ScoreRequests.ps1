# Jev scores urgency; PowerShell adds a label and returns reusable, sorted objects.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../Jev.psd1" -Force

$messages = @(
    'Can you send a brochure? We are planning a purchase next quarter.'
    'Checkout is down right now. No customers can complete purchases.'
    'The tax amount on our invoice is wrong. Our payment run is next month.'
    'Our event starts in two hours and the paid tickets will not download.'
    'Everything works now. Thank you for the quick fix!'
    'Large exports crash, but smaller files work. We can use that workaround for now.'
    'Could we book a product demo next month? Any weekday is fine.'
    'Please correct the duplicate charge before our finance approval window closes at 3 pm today.'
    'I cannot sign in to my account. I need it for a project starting next week.'
    'All 60 staff are locked out and our customer training session starts in one hour.'
    'How do annual plans work? We might switch at next year''s renewal.'
    'Mobile uploads fail. I am in the field and the client report is due in 45 minutes.'
)

$scored = foreach ($message in $messages) {
    $urgency = $message |
        Get-JevScore 'How urgent is this?' 'Can wait' 'Needs attention soon' 'Needs attention now'

    [pscustomobject]@{
        Urgency = $urgency
        UrgencyLabel = switch ($urgency) {
            { $_ -ge 1.5 } { 'Needs attention now'; break }
            { $_ -ge 0.5 } { 'Needs attention soon'; break }
            default        { 'Can wait' }
        }
        Message = $message
    }
}

$scored | Sort-Object Urgency -Descending
