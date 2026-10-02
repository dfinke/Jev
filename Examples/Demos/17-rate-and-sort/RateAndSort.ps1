# Score each request and sort the work from hardest to easiest.
param(
    [string] $Path = "$PSScriptRoot/requests",
    [ValidateRange(0.0, 2.0)]
    [double] $SpecialistThreshold = 1.5
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$question = New-JevQuestion -Name complexity -Type Score `
    -Instructions 'How hard is this request to answer?' `
    -Criteria @(
        'A canned reply answers it.'
        'One person can answer it after a look at the account.'
        'It needs a specialist and more than one system.'
    )

$files = @(Get-ChildItem -LiteralPath $Path -Filter '*.txt' -File | Sort-Object Name)
if ($files.Count -eq 0) {
    throw "No .txt request files found in '$Path'."
}

$rankedRequests = foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $sections = $content -split '(?:\r?\n){2}', 2
    if ($sections.Count -ne 2) {
        throw "Request file '$($file.Name)' needs a Subject header, a blank line, and a message body."
    }

    $subjectLine = $sections[0] -split '\r?\n' |
        Where-Object { $_ -match '^Subject:' } |
        Select-Object -First 1
    if (-not $subjectLine) {
        throw "Request file '$($file.Name)' has no Subject header."
    }

    $subject = $subjectLine -replace '^Subject:\s*', ''
    $body = $sections[1].Trim()
    if ([string]::IsNullOrWhiteSpace($body)) {
        throw "Request file '$($file.Name)' has no message body."
    }

    # Send only the message; keep its filename and subject local.
    $decision = $body | Invoke-Jev -Question $question
    $score = [double] $decision.complexity
    $probabilities = $decision.answers.complexity.probabilities

    [pscustomobject]@{
        Id                       = $file.BaseName
        Subject                  = $subject
        Score                    = [math]::Round($score, 2)
        CannedReplyProbability   = [math]::Round([double] $probabilities.'0', 2)
        AccountReviewProbability = [math]::Round([double] $probabilities.'1', 2)
        SpecialistProbability    = [math]::Round([double] $probabilities.'2', 2)
        Route                    = if ($score -ge $SpecialistThreshold) { 'Specialist' } else { 'Front desk' }
    }
}

$rankedRequests | Sort-Object -Property Score -Descending
