<p align="center">
  <img src="assets/jev-logo.svg" alt="Jev by TypeSafe AI" width="260">
</p>

# Jev

## About

**Jev turns messy input into decisions your PowerShell scripts can act on.**

Jev asks typed questions—yes/no, choice, and score—and returns consistent, structured decisions through a PowerShell-friendly interface. It connects PowerShell to [TypeSafe AI's Jev model](https://typesafe.ai/blog/introducing-system-one-models-and-jev).

This repository contains the PowerShell module and is being prepared for its first preview publication to the PowerShell Gallery.

Question definitions use the same names as the Jev payload: `Type` maps to
`type`, `Instructions` maps to `instructions`, and `Criteria` maps to
`criteria`. `Name` becomes the key that identifies the answer.

## Current status

The `0.1.0` preview is ready for manual publication. The API and examples may continue to evolve as Jev develops.

## Planned usage

```powershell
Import-Module Jev

$questions = @(
    New-JevQuestion -Name churn -Type Noul `
        -Instructions 'Is this an active churn threat?' `
        -Criteria @{ true = 'The customer may leave.'; false = 'The customer is stable.' }
    New-JevQuestion -Name route -Type Choice `
        -Instructions 'Which team should handle this?' `
        -Criteria @{ support = 'Technical issue'; sales = 'Pricing or renewal issue' }
    New-JevQuestion -Name urgency -Type Score -Instructions 'How urgent is this?' `
        -Criteria @('Can wait', 'This week', 'Today')
)

$feedback = 'The customer says the latest invoice is incorrect and may cancel unless billing fixes it.'
$decision = Invoke-Jev -State $feedback -Question $questions
$decision
```

`Invoke-Jev` enriches the incoming state with the Jev response. Each named answer
is raised to a top-level property for easy pipeline use, while the full
`answers` object is retained. Add `-Raw` when you need only the API response.

It also accepts pipeline input, so existing PowerShell commands can feed Jev
directly:

```powershell
Get-WinEvent -LogName System -MaxEvents 1 |
    Invoke-Jev -Question (New-JevQuestion -Name escalate -Type Noul -Instructions 'Should this Windows event be escalated?')
```

See [`Examples/QuickStart.ps1`](Examples/QuickStart.ps1) for a complete API example. It
keeps the input details next to the response and builds a readable summary that
puts the message next to each decision. Set `TYPESAFE_API_KEY` before running it.

Additional examples:

- [`Examples/RefundTriage.ps1`](Examples/RefundTriage.ps1) follows TypeSafe's refund request example.
- [`Examples/SecurityIncidentTriage.ps1`](Examples/SecurityIncidentTriage.ps1) turns a security alert and its context into a response choice.
- [`Examples/SemanticLogTriage.ps1`](Examples/SemanticLogTriage.ps1) classifies log lines by security risk and root-cause category.

## Module layout

- `Public/` contains the commands exported to module users.
- `Private/` contains implementation helpers and the Jev API client.
- `Tests/` contains the Pester test suite.
- [`CHANGELOG.md`](CHANGELOG.md) records the release history.

## Local scripts

`InstallModule.ps1` copies the module into a PowerShell module directory with
`robocopy`:

```powershell
.\InstallModule.ps1 -FullPath "$HOME\Documents\PowerShell\Modules\Jev"
```

## License

This project is licensed under the [MIT License](LICENSE).
