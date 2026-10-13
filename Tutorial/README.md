# Jev in PowerShell: from a question to a guarded action

PowerShell already moves objects through a pipeline. Jev adds a way to ask
typed questions about the meaning of that data: does this need a reply, which
team owns it, or which log line best explains a failure?

The core pattern is simple: **Jev judges; PowerShell decides what to do.** Jev
returns structured answers and probabilities. Your script owns thresholds,
policy, approvals, and any side effects.

This tutorial uses one small support inbox to introduce the module's commands,
then connects them to a wider guardrail pattern for tool-using agents. The
examples are live requests, so outputs can vary. Use them as a learning path or
run each section as a short livestream demo.

For a clickable version, run the WPF lesson viewer:

```powershell
./Tutorial/Start-Tutorial.ps1
```

Choose a lesson to inspect its script and input, edit either one, then run it
to see the result. The viewer runs your edited script and input from a temporary
copy, leaving the tutorial files untouched. The viewer requires Windows and a
`TYPESAFE_API_KEY`; it runs each lesson in the background so the window remains
responsive, and shows elapsed time while the script runs and when it completes.
Use Ctrl+Enter to run a lesson or hover over **Clear results** to see its shortcut.

## Before you start

You need the Jev module and a TypeSafe API key in `TYPESAFE_API_KEY`. From the
repository root, load the local checkout and read the sample messages:

```powershell
Import-Module ./Jev.psd1 -Force
$messages = Get-Content ./Tutorial/messages.txt
```

The sample file contains eight short requests: some need action, some need a
reply, and some are routine. Keep it open while you work through the examples.

## 1. Ask one yes-or-no question

Start with one state and one question. `Test-Jev` turns Jev's yes probability
into an ordinary PowerShell Boolean using its threshold (default `0.5`):

```powershell
$state = @'
Your support team was fantastic.
I still have to rebuild my saved filters every time I sign in.
Can you help me keep them?
'@

$question = 'Is the customer reporting an unresolved product problem?'

$state | Test-Jev $question
```

The result is `True` or `False`. The numbered script shows the state beside
that result:

```powershell
./Tutorial/01-Ask-YesNo.ps1
```

Once that makes sense, send a whole list of states through the same question:

```powershell
$messages | Test-Jev 'Does this message need a reply?'
```

There is one request per message. `Test-Jev` is useful when the next step only
needs true or false. Use `Invoke-Jev` when you want the probability and the
full answer details.

## 2. Route a support ticket with Choice

Choice compares the state against a small set of named outcomes. Here, the
ticket mentions a broken export, a browser-specific impact across half the
team, and a near-term board meeting. The question and criteria define the
answer space; Jev returns the best-matching queue:

```powershell
$state = @'
Export to CSV has been broken since Friday.
It works in Chrome, but half our team is on Safari and they can't pull reports at all.
We have a board meeting Thursday.
'@

$question = New-JevQuestion -Name department -Type Choice `
    -Instructions 'Which queue should own this ticket?' `
    -Criteria @{
        bug_triage        = 'A defect in a specific feature, reproducible, goes into the backlog'
        incident_response = 'A live breakage affecting multiple users right now, needs a responder today'
        customer_success  = 'The account needs managing, not the code'
    }

$state | Invoke-Jev -Question $question | Select-Object State, department
```

Run the example with:

```powershell
./Tutorial/02-Route-Ticket.ps1
```

The returned label is `incident_response` when Jev judges the multi-user,
time-sensitive breakage to fit that queue best. Choice returns one of the
criteria keys; it does not execute the routing action.

## 3. Keep the matching messages

Often the useful result is the original input, filtered by meaning. `Select-Jev`
keeps messages whose yes probability meets the threshold:

```powershell
$messages | Select-Jev 'Does this message need a reply?'
```

Run the next script to see the filtered message stream:

```powershell
./Tutorial/03-Select-Messages.ps1
```

It returns the matching message text, ready for another PowerShell command.
An item that does not pass the threshold may be a no or an uncertain answer;
exclusion alone does not tell you which.

## 4. Find one best match or rank several

These operations look similar, but answer different questions.

Use `Find-Jev` when the candidates should be compared together and you want
the single best fit:

```powershell
$messages | Find-Jev 'Which message most clearly reports a current service outage?'
```

Run it with:

```powershell
./Tutorial/04-Find-BestMatch.ps1
```

Use `Get-JevRanking` when each item should be judged independently against the
same question and you want the strongest few:

```powershell
$messages | Get-JevRanking 'Which message most needs attention today?' -Top 3
```

Run it with:

```powershell
./Tutorial/05-Rank-ByUrgency.ps1
```

`Find-Jev` makes one Choice request for up to 254 candidates. `Get-JevRanking`
makes one Noul request per input, then sorts the original inputs in PowerShell.
`-Top 3` limits the output; all inputs are still evaluated.

## 5. Add a category and route it

When you want the decision alongside the message, define a Choice question.
The criteria describe what each answer means:

```powershell
$team = New-JevQuestion -Name team -Type Choice `
    -Instructions 'Which team should handle this message?' `
    -Criteria @{
        billing = 'A charge, invoice, payment, or refund issue.'
        support = 'A product feature or service is broken.'
        sales   = 'A product, shipping, or plan question.'
        other   = 'The message does not fit the other categories.'
    }
```

`Add-JevAnnotation` adds the answer to each original message as a PowerShell
object. PowerShell can then map the category to a queue:

```powershell
$messages |
    Add-JevAnnotation -Question $team |
    ForEach-Object {
        $queue = switch ($_.team) {
            billing { 'Payments' }
            support { 'Product support' }
            sales   { 'Sales' }
            default { 'General triage' }
        }

        [pscustomobject]@{
            Message = $_.State
            Team    = $_.team
            Queue   = $queue
        }
    } |
    Format-Table -Wrap
```

Run the complete example with:

```powershell
./Tutorial/06-Annotate-And-Route.ps1
```

The model classifies the message. The `switch` is ordinary PowerShell policy.
That separation is useful: you can change queue names or add approval rules
without changing the Jev question.

## 6. Score urgency

Choice answers select one label. A Score question puts each message on an
ordered scale. `Get-JevScore` returns a numeric value that PowerShell can sort:

```powershell
$messages | ForEach-Object {
    $message = $_
    $score = $message | Get-JevScore 'How urgent is this message?' `
        'Can wait' 'Needs attention soon' 'Needs attention now'
    [pscustomobject]@{ Urgency = $score; Message = $message }
} | Sort-Object Urgency -Descending
```

Three levels have numeric anchors `0`, `1`, and `2`; a score can fall between
them. It is not a probability. Run the complete example with:

```powershell
./Tutorial/07-Score-Urgency.ps1
```

## 7. Apply overlapping tags

Sometimes one category is too limiting. `Add-JevTag` asks an independent
yes-or-no question for each label, so a message may get several tags:

```powershell
$tags = [ordered]@{
    billing        = 'A charge, invoice, payment, or refund issue.'
    service_down   = 'An outage prevents people from using the product.'
    time_sensitive = 'The message describes a near-term deadline.'
}

$messages | Add-JevTag $tags -Threshold 0.75 |
    Select-Object State, Tags
```

All labels for one message share one Jev request. The threshold is a local
policy; a missing tag means it did not pass that cutoff, which may include an
uncertain judgment. Run the complete example with:

```powershell
./Tutorial/08-Tag-Messages.ps1
```

## 8. Put a guardrail in front of a tool

The same split applies when an agent or script can call tools. A free-form
request might need semantic interpretation, but a typed answer should not
directly authorize a consequential action.

For example, this script classifies several requests, applies the same local
policy to each, and prints a preview for every one. The sample includes a
read-only check, production and staging restarts, a destructive request, and an
unclear request. It does not call a service or make a change:

```powershell
./Tutorial/09-Guarded-Tool-Preview.ps1
```

A safe orchestration flow can:

1. Use Jev to classify an ambiguous request or identify when it is unclear.
2. Use PowerShell policy to check required fields, environment, permissions,
   risk thresholds, and approval requirements.
3. Show a preview before a tool performs an action.
4. Verify the result and record both approvals and denials.

This is the same separation used in policy-aware agent designs: an execution
tool enforces what an API accepts; a governance layer decides what an
organization permits. In a PowerShell workflow, Jev can help interpret intent,
while PowerShell policy and the tool boundary control the action. Typed output
constrains the answer shape; it does not make a judgment infallible or immune
to misleading input.

For a livestream, the first four sections make a short introduction. Scoring,
overlapping tags, and the guarded preview provide material for a longer session.

## 9. Build a ticket router in one Jev call

The standalone capstone follows DataCamp's
[Building a Ticket Router in One Jev Call](https://www.datacamp.com/tutorial/jev-api-tutorial).
It starts with the same Safari CSV-export ticket, asks six questions of that
single state, and keeps routing policy in PowerShell. Run the script to open its
own WPF window with selectable raw ticket examples. The question definitions
are at the top of the script, ready to inspect while the UI is open.

```powershell
./Tutorial/10-Ticket-Router.ps1
```

Jev judges the queue, goodwill risk, time sensitivity, reproducibility, money
impact, and whether the ticket is automated in one request. PowerShell then
applies the thresholds and produces the route. The example does not connect to
a ticketing system or perform an action.

## What to remember

- Use `Test-Jev` when the caller needs a Boolean.
- Use `Select-Jev` to keep original inputs that meet a yes-probability cutoff.
- Use `Find-Jev` to compare candidates together; use `Get-JevRanking` to
  evaluate candidates independently and sort them.
- Use `Add-JevAnnotation` when the answer belongs beside the input.
- Use `Get-JevScore` for ordered ratings and `Add-JevTag` when multiple labels
  may apply.
- Keep thresholds, routing, approvals, and side effects in PowerShell.
- Treat Jev probabilities as model judgments. Choose thresholds to match the
  cost of a wrong action, and keep a human path for consequential decisions.

## Further reading

- [Tutorial research notes](Research-Notes.md) — links and takeaways behind
  this PowerShell learning path.
- [ThinkThen tutorial](https://thinkthen.dev/learn/tutorial/) — a shell-first
  walkthrough that inspired this learning path.
- [ThinkThen demos](https://github.com/botassembly/thinkthen/tree/main/demos) —
  the source of several PowerShell demo patterns in this repository.
- [DSPy decision-making with Jev types](https://dspy.ai/current/tutorials/jev_decisions/) —
  another way to compose typed Jev decisions inside a programming framework.
- [BigQuery AI.CLASSIFY](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-classify) —
  an example of semantic classification exposed as a familiar data operation.
- [Jev pipelines](../Examples/Pipelines/README.md) — complete runnable examples
  using the PowerShell module.
- [Jev PowerShell demos](../Examples/Demos/README.md) — short teaching demos,
  including filtering, routing, finding, ranking, and guarded workflows.
