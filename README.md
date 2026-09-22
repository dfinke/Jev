# Jev

## About

**Turn messy input into decisions your PowerShell scripts can act on.**

Jev asks typed questions—yes/no, choice, and score—and returns consistent, structured decisions through a PowerShell-friendly interface. It connects PowerShell to [TypeSafe AI's Jev model](https://typesafe.ai/blog/introducing-system-one-models-and-jev).

This repository contains the PowerShell module and is being prepared for publication to the PowerShell Gallery.

## Current status

Early development. The public wrapper is taking shape while the decision engine and module packaging are being refined.

## Planned usage

```powershell
Import-Module Jev

$questions = @(
    New-JevQuestion -Name churn -Type Noul -Prompt 'Is this an active churn threat?'
    New-JevQuestion -Name urgency -Type Score -Prompt 'How urgent is this?' `
        -Level 'Can wait' -Level 'This week' -Level 'Today'
)

$decision = Invoke-Jev -InputObject $feedback -Question $questions
```

## License

License to be determined.
