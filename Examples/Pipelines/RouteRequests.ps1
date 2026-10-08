# Jev chooses one team; PowerShell maps that label to a queue.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../Jev.psd1" -Force

$requests = @(
    [pscustomobject]@{ Id = 'REQ-01'; Message = 'I was charged twice. Please refund the duplicate payment.' }
    [pscustomobject]@{ Id = 'REQ-02'; Message = 'My order has not arrived and tracking has not changed in a week.' }
    [pscustomobject]@{ Id = 'REQ-03'; Message = 'I cannot sign in and every password reset link has expired.' }
    [pscustomobject]@{ Id = 'REQ-04'; Message = 'Could you consider adding dark mode in a future release?' }
    [pscustomobject]@{ Id = 'REQ-05'; Message = 'The tax amount on my invoice is wrong. Please correct it.' }
    [pscustomobject]@{ Id = 'REQ-06'; Message = 'The courier returned my package to you. Can you send it again?' }
    [pscustomobject]@{ Id = 'REQ-07'; Message = 'Our new colleague cannot activate their account with the invitation link.' }
    [pscustomobject]@{ Id = 'REQ-08'; Message = 'Can we book a product demonstration for our team next month?' }
)

$results = foreach ($request in $requests) {
    $team = $request |
        Get-JevChoice 'Which team owns this request?' billing shipping account other

    $queue = switch ($team) {
        billing  { 'payments' }
        shipping { 'logistics' }
        account  { 'identity' }
        other    { 'triage' }
    }

    [pscustomobject]@{
        Id      = $request.Id
        Team    = $team
        Queue   = $queue
        Message = $request.Message
    }
}

$results | Format-Table -Wrap
