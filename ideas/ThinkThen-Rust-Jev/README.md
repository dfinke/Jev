# ThinkThen example in PowerShell

`Invoke-JevChoice.ps1` supplies a small PowerShell helper over Jev. With Jev loaded, the question and choices are positional, as in the shell example:

```powershell
. ./ideas/ThinkThen-Rust-Jev/Invoke-JevChoice.ps1
Get-Content ./ideas/ThinkThen-Rust-Jev/ticket.txt -Raw |
    Invoke-JevChoice 'Which team owns this request?' billing shipping account other
```

It returns the chosen label. Add `-Threshold 0.8` to return `not_sure` when confidence is below that cutoff. The choice labels themselves become the Jev criteria.

`Route-Ticket.ps1` asks which team owns `ticket.txt`, uses a `0.8` confidence threshold, and maps the label to a queue with `switch`. Lower confidence goes to `triage`. It checks that the supplied billing ticket produces `queue=payments`. Run it with `TYPESAFE_API_KEY` configured:

```powershell
.\ideas\ThinkThen-Rust-Jev\Route-Ticket.ps1
```

The PowerShell equivalent of the pictured `thinkthen decide` example:

```powershell
$question = 'Does the customer ask for a refund?'

@'
I renewed once this morning, but my card shows two charges.
Please refund the duplicate.
'@ | Test-Jev $question
```

Expected output:

```text
True
```

From the repository root, with PowerShell 7 and `TYPESAFE_API_KEY` configured:

```powershell
.\ideas\ThinkThen-Rust-Jev\RefundQuestion.ps1
```

Each run makes one live Jev request. The script imports the repository's Jev module and loads the demo-local `Test-Jev.ps1` helper, since `main` does not export `Test-Jev` yet. This folder contains PowerShell code; it does not require the Rust CLI.

PowerShell returns a Boolean through the pipeline. The shell image also shows an exit status; this example uses PowerShell's object output and does not set a process exit code from the decision.

## A predicate, a route, and a check

`Route-CustomerMessage.ps1` translates the shell function-and-branch example into PowerShell:

```powershell
.\ideas\ThinkThen-Rust-Jev\Route-CustomerMessage.ps1
```

It reads `question.txt` as one complete message using `Get-Content -Raw`, pipes it into `Test-MoneyBackRequest`, and chooses `refunds` or `normal`. The supplied message asks for a receipt, so the expected output is:

```text
normal
```

The script throws if the route differs from `normal`, matching the purpose of `mustmatch "normal"`. Change the message to request a refund and the check should fail with `Expected 'normal', got 'refunds'.`

`Set-StrictMode` catches undefined-variable mistakes, and `$ErrorActionPreference = 'Stop'` stops execution on errors. The Jev module has no equivalent to ThinkThen's `--replay recording/`; this example makes one live request. The predicate already returns only a Boolean, so it needs no `--quiet` switch.
