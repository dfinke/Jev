Import-Module jev

$emails = @(
    @{
        sender  = 'Maya Chen <maya@northwind.example>'
        subject = 'Re: Revised renewal quote'
        body    = 'The revised quote looks good. Can you confirm that onboarding is included before I send it to procurement?'
        history = 'We sent Maya revised pricing yesterday. This onboarding question has not been answered yet.'
    }
    @{
        sender  = 'Jordan Lee <jordan@northwind.example>'
        subject = 'Friday release notes'
        body    = 'Sharing the release notes for your records. No response is needed.'
        history = 'There is no open question or outstanding request from Jordan.'
    }
    @{
        sender  = 'Alex Morgan <alex@northwind.example>'
        subject = 'Re: Project update'
        body    = 'I added the changes we discussed. Let me know if you had something else in mind.'
        history = 'The earlier thread is not available, so it is unclear whether Alex is waiting for a review.'
    }
)

$emails.Jev('Do I need to reply?') | ForEach-Object {

    $decision = $_.decision
    $needsResponse = 
    if ($decision -ge 0.8 ) { 'Yes' }
    elseif ($decision -le 0.2) { 'No' }
    else { 'Review' }

    [pscustomobject]@{
        Sender        = $_.sender
        NeedsResponse = $needsResponse
        Decision      = $decision
    }
}