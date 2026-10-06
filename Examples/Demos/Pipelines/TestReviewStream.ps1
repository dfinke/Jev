# Test each review for a complaint and keep the Boolean result beside the review.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1" -Force

$question = 'Is this a complaint?'
$reviews = @(
    'Arrived a day early. Thank you!'
    'The zipper broke the first time I used it.'
    'Does this come in blue?'
    'The strap snapped on day two.'
)

foreach ($review in $reviews) {
    [pscustomobject][ordered]@{
        IsComplaint = $review | Test-Jev $question
        Review      = $review
    }
}
