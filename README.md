# Jev

## About

**Turn messy input into decisions your PowerShell scripts can act on.**

Jev asks typed questions—yes/no, choice, and score—and returns consistent, structured decisions through a PowerShell-friendly interface. It connects PowerShell to [TypeSafe AI's Jev model](https://typesafe.ai/blog/introducing-system-one-models-and-jev).

This repository contains the PowerShell module and is being prepared for publication to the PowerShell Gallery.

Question definitions use the same names as the Jev payload: `Type` maps to
`type`, `Instructions` maps to `instructions`, and `Criteria` maps to
`criteria`. `Name` becomes the key that identifies the answer.

## Current status

Early development. The public wrapper is taking shape while the decision engine and module packaging are being refined.

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

$decision = Invoke-Jev -InputObject $feedback -Question $questions
```

See [`Examples/QuickStart.ps1`](Examples/QuickStart.ps1) for a complete API example. It
keeps the raw response and builds a readable summary that puts the message
next to each decision. Set `TYPESAFE_API_KEY` before running it.

Additional examples:

- [`Examples/RefundTriage.ps1`](Examples/RefundTriage.ps1) follows TypeSafe's refund request example.
- [`Examples/SecurityIncidentTriage.ps1`](Examples/SecurityIncidentTriage.ps1) turns a security alert and its context into a response choice.

## Module layout

- `Public/` contains the commands exported to module users.
- `Private/` contains implementation helpers and the Jev API client.
- `Tests/` contains the Pester test suite.

## Local scripts

`InstallModule.ps1` copies the module into a PowerShell module directory with
`robocopy`:

```powershell
.\InstallModule.ps1 -FullPath "$HOME\Documents\PowerShell\Modules\Jev"
```

`PublishToGallery.ps1` validates the manifest and publishes the module when
you are ready:

```powershell
.\PublishToGallery.ps1 -NuGetApiKey $apiKey
```

## License

This project is licensed under the [MIT License](LICENSE).
