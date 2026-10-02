# Choose the next action from the record

At each step in a workflow, the available actions can change. This example gives Jev the current state and that step's own list of possible actions, then uses a confidence cutoff to decide whether to accept the suggestion or ask a person.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\21-options-from-the-record\ChooseNextAction.ps1 |
    Format-Table Id, SuggestedAction, Probability, NextStep
```

The three steps follow one package-delivery case. Each JSONL record contains its own `state` and `actions`. The first two action lists are names; the third is a map of action names to descriptions. The script turns names into Choice options and preserves descriptions when supplied. It asks one Choice question per step and sends only that step's state and available actions to Jev.

The result shows Jev's suggested action and its probability. At `0.8` or higher, PowerShell accepts the suggestion for the next step; below that, it returns `ask a person`. The threshold can be changed with `-Threshold`. Nothing here performs the selected action.

This demonstrates changing options across steps, unlike a fixed Choice question such as the ticket-routing demo. Keep each option set short and make the actions distinct. Each step makes one live Jev request; no recording or replay data is used.

Ported from `thinkthen/demos/21-options-from-the-record`, using the existing `New-JevQuestion` and `Invoke-Jev` commands.
