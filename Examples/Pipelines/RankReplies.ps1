# All six messages need replies. Rank them by the need for urgent attention.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../Jev.psd1" -Force

$messages = @(
    'Can you send your product brochure? I am planning a purchase next month.'
    'Our checkout is down right now. No customers can place orders.'
    'Please update the address on our next invoice. There is no rush.'
    'Our event starts in two hours and the paid tickets still will not download.'
    'Could you explain the annual billing options when you have a chance?'
    'We were charged twice today. Please check and arrange a refund.'
)

# Top limits what comes back; Jev still evaluates all six messages.
$messages | Get-JevRanking 'Does this message need urgent attention?' -Top 3
