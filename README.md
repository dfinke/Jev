<p align="center">
  <img src="assets/jev-icon.png" alt="Decision pipeline icon" width="180">
</p>

# Jev

## About

**Jev turns messy input into decisions your PowerShell scripts can act on.**

Jev asks typed questions—yes/no, choice, and score—and returns consistent, structured decisions through a PowerShell-friendly interface. It connects PowerShell to [TypeSafe AI's Jev model](https://typesafe.ai/blog/introducing-system-one-models-and-jev).

For a related PowerShell decision module using Perplexity, see [PSAIPerplexityDecisions](https://github.com/dfinke/PSAIPerplexityDecisions).

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

The `0.4.0` preview adds `Get-JevRanking` for semantic ranking, `Find-Jev` for comparative search, and `Add-JevTag` for applying multiple labels to each input. Combine these with `Select-Jev` and `Add-JevAnnotation` in PowerShell pipelines. Runnable examples are available under `Examples/Pipelines` and `Examples/Demos`. The API and examples may continue to evolve as Jev develops.

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

For a yes/no check where a Boolean is enough, use `Test-Jev`:

```powershell
'The customer says they were charged twice and asks for a refund.' |
    Test-Jev 'Does the customer ask for a refund?'
# True
```

`Test-Jev` compares Jev's yes probability with `-Threshold` (default `0.5`) and
returns `$true` or `$false`. It makes one live request for each piped state, so
answers may vary. Use `Invoke-Jev` when you need the probability or full response.
The question and threshold also accept positional arguments:
`$messages | Test-Jev 'Should this be escalated?' 0.8`.

For pipelines, `Select-Jev` keeps the original inputs that pass a yes/no
question. `Add-JevAnnotation` uses `Invoke-Jev` to enrich each remaining input
with named answers:

```powershell
$messages |
    Select-Jev 'Does this need a reply?' |
    Add-JevAnnotation -Question $kind, $urgency |
    Select-Object State, kind, urgency
```

Here `$kind` and `$urgency` are named Choice and Score questions.
`Select-Jev` defaults to a `0.5` threshold; add `-Threshold 0.8` to require a
higher yes probability. Each input to either command makes one request.
See [Jev pipelines](Examples/Pipelines/README.md) for the complete runnable example.

For semantic ranking, `Get-JevRanking` asks the same yes/no question of each input
and returns the original inputs in descending yes-probability order:

```powershell
$messages | Get-JevRanking 'Does this need urgent attention?' -Top 3
```

Exact ties keep input order. Each input makes one request, and `-Top` only
limits the output. Results are buffered until input ends. To sort an answer
you already obtained, use `Sort-Object` on that property instead.
See [Rank replies](Examples/Pipelines/RankReplies.ps1) for a runnable example.

To compare candidates together and find the one that best answers a question:

```powershell
Get-Content ./Examples/Pipelines/checkout.log |
    Find-Jev 'Which entry best explains why customers cannot complete checkout?'
```

`Find-Jev` makes one Choice request for up to 254 candidates and returns the
original selected string or object. It returns nothing when Jev selects
"none fits"; empty input makes no request. It buffers finite input and does
not apply a confidence cutoff. Request failures remain errors.

See [Find the checkout cause](Examples/Pipelines/FindCheckoutCause.ps1) for
the complete runnable example. `Get-JevRanking` judges inputs independently;
`Find-Jev` lets Jev compare them together.

When several labels can apply, use `Add-JevTag`:

```powershell
$tags = [ordered]@{
    billing = 'A current charge, invoice, payment, or refund problem.'
    account_access = 'A current problem signing in or resetting a password.'
    urgent = 'An unresolved problem with an explicit deadline today.'
}

'I was charged twice and cannot sign in. Our event starts tonight.' |
    Add-JevTag $tags -Threshold 0.8 |
    Select-Object State, Tags
```

Each label is an independent Noul question; several labels or none may match.
All labels share one request per input. The default threshold is `0.5`.
Results include a `Tags` string array, individual probabilities, and full
answers alongside the input properties. Collisions receive `Jev_` prefixes.
An absent tag missed the cutoff, which can include uncertain answers.
See [Tag an inbox](Examples/Pipelines/TagInbox.ps1) for a complete demo.

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

- [Jev pipelines](Examples/Pipelines/README.md) shows how to compose selection and annotation.

- [PowerShell demos](Examples/Demos/README.md) collects the teaching-focused demos.

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
