# A message can have several issues. Tag the inbox once, then explore it in PowerShell.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../Jev.psd1" -Force

$messages = Get-Content "$PSScriptRoot/inbox.json" -Raw | ConvertFrom-Json
$tags = [ordered]@{
    billing        = 'A current charge, invoice, payment, or refund problem. Exclude resolved problems and general pricing questions.'
    account_access = 'A current problem signing in, resetting a password, or accessing an account.'
    delivery       = 'An order is missing, delayed, damaged in transit, or delivered incorrectly. Exclude general shipping questions.'
    product_issue  = 'A software feature is broken or behaving incorrectly. Exclude feature requests and resolved issues.'
    urgent         = 'An unresolved problem has an explicit near-term deadline or is currently blocking many customers.'
    praise         = 'The customer expresses thanks or positive feedback about the product or help received.'
}

# All six tags share one request per message. Keep the results for local queries.
$results = @($messages | Add-JevTag $tags -Threshold 0.8)

Write-Host '=== One inbox. Multiple tags per message.' -ForegroundColor Cyan
$results | Format-Table Id, @{
    Name = 'Tags'
    Expression = { if ($_.Tags.Count) { $_.Tags -join ', ' } else { '(none)' } }
}, Subject -Wrap

Write-Host '=== What is in the inbox? A message can count toward several tags.' -ForegroundColor Cyan
$results | ForEach-Object Tags | Group-Object -NoElement |
    Sort-Object Count -Descending | Format-Table Name, Count

Write-Host '=== Urgent messages with multiple issues:' -ForegroundColor Cyan
$results | Where-Object { $_.Tags -contains 'urgent' -and $_.Tags.Count -gt 1 } |
    Format-Table Id, Subject, Tags -Wrap
