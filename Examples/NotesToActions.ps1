#requires -Version 7.0

[CmdletBinding()]
param(
    [string] $Path
)

# Set TYPESAFE_API_KEY before running this example.

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

if ($Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Notes file not found: $Path"
    }

    $notes = @(Get-Content -LiteralPath $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
else {
    $notes = @(
        'Email Sam the updated mockup before the review on Thursday.'
        'We agreed that the first release will support PowerShell only.'
        'The staging environment is refreshed every Monday morning.'
        'I still need to choose whether to keep the tray icon in version one.'
        'Schedule 30 minutes with Priya to review the onboarding flow.'
        'The customer says importing sales files from last quarter takes too long.'
        'The team decided to hold the public demo until the Gallery package is ready.'
        'Check with finance whether the old invoice format is still required.'
    )
}

$question = New-JevQuestion `
    -Name category `
    -Type Choice `
    -Instructions 'Classify this note by its primary purpose. Choose action for a specific follow-up someone should do, decision for a settled or unresolved choice, or background for context that does not directly call for a task or decision.' `
    -Criteria ([ordered]@{
        action     = 'A concrete task or follow-up for someone to do.'
        decision   = 'A choice or conclusion that has been made, or a choice still to make.'
        background = 'Context, an observation, or an idea with no direct task or decision.'
    })

$results = foreach ($note in $notes) {
    $state = [pscustomobject]@{
        Note = $note.Trim()
    }

    $decision = Invoke-Jev -State $state -Question $question
    $choice = $decision.answers.category

    [pscustomobject]@{
        Category   = $decision.category
        Confidence = [math]::Round([double]$choice.confidence, 2)
        Note       = $decision.Note
    }
}

foreach ($category in 'action', 'decision', 'background') {
    $items = @($results | Where-Object Category -eq $category)
    if ($items.Count -eq 0) { continue }

    Write-Host "`n$($category.ToUpperInvariant())" -ForegroundColor Cyan
    $items | Sort-Object Confidence -Descending | Format-Table Confidence, Note -Wrap
}
