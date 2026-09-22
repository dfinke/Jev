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

See [`Examples/Basic.ps1`](Examples/Basic.ps1) for a complete offline example.

## Module layout

- `Public/` contains the commands exported to module users.
- `Private/` contains implementation helpers and the Jev API client.
- `Tests/` contains the Pester test suite.

## License

This project is licensed under the [MIT License](LICENSE).
