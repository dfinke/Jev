<p align="center">
  <img src="assets/jev-icon.png" alt="Decision pipeline icon" width="180">
</p>

# Jev

## About

**Jev turns messy input into decisions your PowerShell scripts can act on.**

Jev asks typed questions—yes/no, choice, and score—and returns consistent, structured decisions through a PowerShell-friendly interface. It connects PowerShell to [TypeSafe AI's Jev model](https://typesafe.ai/blog/introducing-system-one-models-and-jev).

This repository contains the PowerShell module. Gallery publication is handled separately from GitHub releases.

Set `TYPESAFE_API_KEY`, then try two checkout incidents:

```powershell
Import-Module Jev

$question = New-JevYesNoQuestion -Name pageOnCall `
    -Question 'Should the on-call engineer be paged now?' `
    -TrueCriteria 'Customers cannot complete purchases' `
    -FalseCriteria 'Purchases are working normally'

@(
    'Checkout is returning HTTP 503 errors; customers cannot place orders.'
    'Checkout is healthy; customers are placing orders normally with no errors.'
) |
    Invoke-Jev -Question $question |
    Select-Object State, @{
        Name       = 'pageOnCall'
        Expression = { if ($_.pageOnCall -ge 0.8) { 'page' } else { 'do not page' } }
    }
```

Illustrative output:

```text
State                                                                       pageOnCall
-----                                                                       ----------
Checkout is returning HTTP 503 errors; customers cannot place orders.       page
Checkout is healthy; customers are placing orders normally with no errors.  do not page
```

`New-JevYesNoQuestion` creates a Noul question. Jev returns a probability of
"yes" in `pageOnCall`; the calculated `Select-Object` property turns that
number into a readable label. The `0.8` cutoff is an example paging policy,
not a Jev default. Scores below it display `do not page`, including uncertain
ones. [`Examples/PageOnCall.ps1`](Examples/PageOnCall.ps1) shows a separate
`Review` outcome for uncertain incidents.

For full control, `New-JevQuestion` uses names that match the Jev payload:
`Type` maps to `type`, `Instructions` to `instructions`, and `Criteria` to
`criteria`. `Name` becomes the answer key. The yes/no question above is
equivalent to:

```powershell
$question = New-JevQuestion -Name pageOnCall -Type Noul `
    -Instructions 'Should the on-call engineer be paged now?' `
    -Criteria @{
        true  = 'Customers cannot complete purchases'
        false = 'Purchases are working normally'
    }
```

## Current status

The `0.2.0` preview adds a yes/no question helper, array `.Jev()` method, JSON output, and new examples. The API and examples may continue to evolve as Jev develops.

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
Use `-AsJson` to display the result as JSON while exploring; combine it with
`-Raw` to see the raw API response as JSON.

```powershell
Invoke-Jev -State $feedback -Question $questions -AsJson
Invoke-Jev -State $feedback -Question $questions -Raw -AsJson
```

`-AsJson` returns JSON text, so use the default object output when you want to
filter or sort the decisions in a PowerShell pipeline.

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
- [`Examples/NotesToActions.ps1`](Examples/NotesToActions.ps1) sorts rough notes into actions, decisions, and background; pass `-Path` to read notes from a text file.
- [`Examples/ReleaseNotes.ps1`](Examples/ReleaseNotes.ps1) reviews recent Git commit subjects and builds a draft release-note list for human review.
- [`Examples/StandupReport.ps1`](Examples/StandupReport.ps1) organizes recent repo commits, shows working-tree changes, and accepts your plan and blockers as input.
- [`Examples/PowerShellCommandFinder.ps1`](Examples/PowerShellCommandFinder.ps1) searches local command help for candidates, asks Jev which best fits a plain-English task, and displays examples without running the command.
- [`Examples/DealDesk.ps1`](Examples/DealDesk.ps1) calculates quote options from an editable Excel deal, then asks Jev to recommend the next negotiation move. Requires ImportExcel and `TYPESAFE_API_KEY`.
- [`Examples/PageOnCall.ps1`](Examples/PageOnCall.ps1) evaluates checkout incidents against an example paging policy and shows when to page, hold, or review.

Try it with tasks such as:

```powershell
.\Examples\PowerShellCommandFinder.ps1 -Task 'Find files larger than 100 MB'
.\Examples\PowerShellCommandFinder.ps1 -Task 'Show processes using the most memory' -CandidateCount 18
.\Examples\PowerShellCommandFinder.ps1 -Task 'Search text inside every PowerShell script'
```

For the deal desk, edit the `Deal` sheet in [`data/DealDesk.xlsx`](data/DealDesk.xlsx), then run:

```powershell
.\Examples\DealDesk.ps1
```

Each run writes a separate review workbook with the recommendation and all priced options. PowerShell calculates revenue and margin; Jev selects among moves that meet the margin floor and buyer budget. Other moves remain visible for human review. The confidence is Jev's confidence in its choice, not a forecast of whether the deal will close.

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
