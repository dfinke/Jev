param(
    [ValidateRange(1, 50)]
    [int] $MinBurstSize = 3,

    [ValidateRange(1, 50)]
    [int] $MaxBurstSize = 10,

    [ValidateRange(1, 60)]
    [int] $MinPauseSeconds = 3,

    [ValidateRange(1, 60)]
    [int] $MaxPauseSeconds = 10,

    [string] $RunDirectory = (Join-Path $env:TEMP 'Jev-Live-Routing')
)

if ($MinBurstSize -gt $MaxBurstSize) {
    throw 'MinBurstSize must be less than or equal to MaxBurstSize.'
}

if ($MinPauseSeconds -gt $MaxPauseSeconds) {
    throw 'MinPauseSeconds must be less than or equal to MaxPauseSeconds.'
}

$categories = @('billing', 'account', 'bug', 'feature_request', 'how_to', 'other')
$runDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$queueDirectory = Join-Path $runDirectory 'Queues'
$messagePath = Join-Path $runDirectory 'messages.jsonl'
$generatorStatusPath = Join-Path $runDirectory 'generator-status.json'
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)

$messageBank = @(
    [pscustomobject]@{ Category = 'billing'; Message = 'I see two charges for order A-1048. Please refund the duplicate.' }
    [pscustomobject]@{ Category = 'billing'; Message = 'The renewal invoice still includes the plan we canceled last month.' }
    [pscustomobject]@{ Category = 'billing'; Message = "Could you email me a receipt for yesterday's subscription payment?" }
    [pscustomobject]@{ Category = 'billing'; Message = 'Our card was charged after we downgraded to the free plan.' }
    [pscustomobject]@{ Category = 'billing'; Message = 'The invoice total does not match the quote we approved.' }
    [pscustomobject]@{ Category = 'billing'; Message = 'Can you explain when our annual subscription renews?' }
    [pscustomobject]@{ Category = 'billing'; Message = 'A refund was approved last week, but it is not on the account yet.' }
    [pscustomobject]@{ Category = 'account'; Message = 'My password reset link expires as soon as I open it, so I cannot sign in.' }
    [pscustomobject]@{ Category = 'account'; Message = 'I changed my work email and now the account says it cannot find me.' }
    [pscustomobject]@{ Category = 'account'; Message = 'Please help me restore access after my authenticator phone was replaced.' }
    [pscustomobject]@{ Category = 'account'; Message = 'I am locked out after too many sign-in attempts. Can you unlock my account?' }
    [pscustomobject]@{ Category = 'account'; Message = 'My invitation says it has already been used, but I have never signed in.' }
    [pscustomobject]@{ Category = 'account'; Message = 'Can you remove my old phone number from two-step verification?' }
    [pscustomobject]@{ Category = 'account'; Message = 'I need to change the email address connected to my profile.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'Exporting this report fails with an error in Safari, but works in Chrome.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'The Save button spins forever after I add a second project member.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'Search results disappear when I sort by newest first.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'The dashboard total is different from the number shown in the downloaded report.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'After the update, the date picker closes before I can select an end date.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'Clicking Archive gives me a success message, but the item stays in the list.' }
    [pscustomobject]@{ Category = 'bug'; Message = 'The app crashes whenever I open a project with more than 100 tasks.' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'It would save time if I could schedule this report to run every Monday.' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'Could you add bulk tagging so I can update a whole page of contacts?' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'I would like a dark theme for the dashboard.' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'It would help to export the activity timeline as a PDF.' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'Could we get a keyboard shortcut for creating a new report?' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'Please add a way to compare this month with the same month last year.' }
    [pscustomobject]@{ Category = 'feature_request'; Message = 'I would like to assign more than one owner to a project.' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'How do I invite another analyst to our workspace?' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'Where can I find the reports I saved last week?' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'Can you show me how to change the default date range?' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'How can I share a dashboard with someone outside my team?' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'Where do I update the notification settings for weekly reports?' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'How do I restore a project that I archived by mistake?' }
    [pscustomobject]@{ Category = 'how_to'; Message = 'Can I filter the activity list to show only changes made by me?' }
    [pscustomobject]@{ Category = 'other'; Message = 'Your team made onboarding much easier for us. Thanks!' }
    [pscustomobject]@{ Category = 'other'; Message = 'Is there a webinar or community meetup coming up this month?' }
    [pscustomobject]@{ Category = 'other'; Message = 'I noticed the office will be closed Friday. Hope everyone enjoys the long weekend.' }
    [pscustomobject]@{ Category = 'other'; Message = 'We are evaluating a few tools and will make a decision later this quarter.' }
    [pscustomobject]@{ Category = 'other'; Message = 'Your recent product update looks great. The new layout is much easier to scan.' }
    [pscustomobject]@{ Category = 'other'; Message = 'Could someone send me information about your partner program?' }
    [pscustomobject]@{ Category = 'other'; Message = 'I have a question about your data retention policy for former customers.' }
)

New-Item -ItemType Directory -Path $queueDirectory -Force | Out-Null

# Start each demo with a clean input stream and empty queue files.
[System.IO.File]::WriteAllText($messagePath, '', $utf8WithoutBom)
[System.IO.File]::WriteAllText($generatorStatusPath, (@{ totalGenerated = 0; lastBurst = 0; lastPauseSeconds = 0; updatedUtc = [DateTimeOffset]::UtcNow.ToString('O') } | ConvertTo-Json -Compress), $utf8WithoutBom)
foreach ($category in $categories) {
    $queuePath = Join-Path $queueDirectory "$category.jsonl"
    [System.IO.File]::WriteAllText($queuePath, '', $utf8WithoutBom)
}
[System.IO.File]::WriteAllText((Join-Path $queueDirectory '_failed.jsonl'), '', $utf8WithoutBom)

Write-Host 'Jev live message generator' -ForegroundColor Cyan
Write-Host "Writing messages to: $messagePath"
Write-Host "Queues will be saved in: $queueDirectory"
Write-Host 'Start Watch-Routing.ps1 in another console. Press Ctrl+C to stop.'
Write-Host ''

$messageNumber = 0

while ($true) {
    $burstSize = Get-Random -Minimum $MinBurstSize -Maximum ($MaxBurstSize + 1)
    $burstLines = [System.Collections.Generic.List[string]]::new()

    for ($index = 0; $index -lt $burstSize; $index++) {
        $messageNumber++
        $sample = Get-Random -InputObject $messageBank
        $record = [ordered]@{
            id        = 'MSG-{0:D6}' -f $messageNumber
            createdUtc = [DateTimeOffset]::UtcNow.ToString('O')
            message   = $sample.Message
        }
        $burstLines.Add(($record | ConvertTo-Json -Compress -Depth 4))
    }

    $jsonLines = $burstLines -join [Environment]::NewLine
    [System.IO.File]::AppendAllText($messagePath, $jsonLines + [Environment]::NewLine, $utf8WithoutBom)

    $pause = Get-Random -Minimum $MinPauseSeconds -Maximum ($MaxPauseSeconds + 1)
    $generatorStatus = [ordered]@{
        totalGenerated   = $messageNumber
        lastBurst        = $burstSize
        lastPauseSeconds = $pause
        updatedUtc       = [DateTimeOffset]::UtcNow.ToString('O')
    }
    [System.IO.File]::WriteAllText($generatorStatusPath, ($generatorStatus | ConvertTo-Json -Compress), $utf8WithoutBom)
    Write-Host ('Wrote {0} messages ({1} total). Pausing {2} seconds.' -f $burstSize, $messageNumber, $pause) -ForegroundColor Green
    Start-Sleep -Seconds $pause
}
