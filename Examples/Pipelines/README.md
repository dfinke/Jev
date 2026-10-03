# Jev pipelines

Small, runnable examples of using Jev judgments in a PowerShell pipeline.
Set `TYPESAFE_API_KEY` before running them. The scripts import the module from
this checkout, so you can try changes directly from a development branch.

| Example | What it teaches |
| --- | --- |
| [Reply triage](ReplyTriage.ps1) | Select messages needing a reply, then add category and urgency answers. |
| [Rank replies](RankReplies.ps1) | Rank six messages by need for urgent attention and return the top three. |
| [Prioritize an inbox](PrioritizeInbox.ps1) | Filter, rank, and annotate messages in one pipeline to build a prioritized worklist. |
| [Find the checkout cause](FindCheckoutCause.ps1) | Compare sixteen log lines together and select the one that best explains a checkout failure. |
| [Tag an inbox](TagInbox.ps1) | Apply six overlapping tags to eighteen messages, then count tags and surface urgent messages with multiple issues. |
| [Route requests](RouteRequests.ps1) | Choose one team with compact arguments, then use switch to select a queue for eight requests. |
| [Score requests](ScoreRequests.ps1) | Rate twelve messages on an urgency scale, then sort the scored messages with PowerShell. |

## Reply triage

Four messages enter the pipeline. One only says thank you. The others report
an invoice problem, a missing delivery needed tonight, and a shipping question.

Run from the repository root:

```powershell
./Examples/Pipelines/ReplyTriage.ps1
```

The central pipeline is:

```powershell
$messages |
    Select-Jev 'Does this message need a reply?' |
    Add-JevAnnotation -Question $kind, $urgency |
    Format-Table State, kind, urgency -Wrap
```

Illustrative output; live answers and scores can vary:

```text
State                                        kind     urgency
-----                                        ----     -------
Please fix the wrong amount on my invoice.    billing      0.6
Order never arrived and the party is tonight. delivery     2.0
Do you ship to Canada?                       question     0.1
```

`Select-Jev` asks a Noul question and keeps inputs whose yes probability is
at least `0.5`. It emits the original matching strings or objects, in input
order. To set a different cutoff, use `-Threshold 0.8`. Being excluded means
the answer missed your cutoff, which does not necessarily mean a confident no.
Failed requests remain errors.

`Add-JevAnnotation` asks a Choice question and a Score question together for
each remaining message. It returns an enriched object, using the same behavior
as `Invoke-Jev`. Strings become a `State` property; object inputs retain their
properties alongside the answers. The original input is not modified.

The urgency scale has three levels: 0 for Routine, 1 for Soon, and 2 for
Immediate. Its weighted score can fall between levels; it is not a probability.
The full distributions remain under `answers`.

Each input to either command makes one live request. If three of the four
messages pass, this pipeline makes seven requests: four selection requests and
three annotation requests. The two annotation questions share each request.

The final `Format-Table` displays the results. Replace it with `Select-Object`,
`Group-Object`, or `Export-Csv` to continue using the enriched objects.

## Rank replies

All six messages need a reply, but some need action sooner than others. Run:

```powershell
./Examples/Pipelines/RankReplies.ps1
```

The central pipeline is:

```powershell
$messages | Get-JevRanking 'Does this message need urgent attention?' -Top 3
```

Illustrative output; live judgments and ordering can vary:

```text
Our checkout is down right now. No customers can place orders.
Our event starts in two hours and the paid tickets still will not download.
We were charged twice today. Please check and arrange a refund.
```

`Get-JevRanking` provides semantic ranking. It asks the same Noul question about
each message, then sorts by the yes probabilities in PowerShell. It returns
the original strings or objects, highest probability first. It preserves input
order for exact ties and never adds ranking properties to the original input.

`-Top 3` limits the output to three messages. All six are evaluated, making six
requests. Omit `-Top` to return all inputs in ranked order. A low probability
still has a place in that order; ranking does not apply a filtering threshold.

Results are buffered until input ends. Use finite input rather than an
unending log stream. To rank only relevant records, compose the commands:

```powershell
$messages |
    Select-Jev 'Does this need a reply?' |
    Get-JevRanking 'Does this need urgent attention?' -Top 3
```

If you already have an annotated numeric property, use `Sort-Object` to sort
that value without making another Jev request:

```powershell
$messages |
    Add-JevAnnotation -Question $urgency |
    Sort-Object urgency -Descending
```

Here `$urgency` is a named Score question, as defined in the reply-triage example.

## Prioritize an inbox

Turn five messages into a prioritized worklist with a team assigned to each item:

```powershell
./Examples/Pipelines/PrioritizeInbox.ps1
```

The three commands each have one job:

```powershell
$messages |
    Select-Jev 'Does this need a reply?' |
    Get-JevRanking 'Does this need urgent attention?' -Top 3 |
    Add-JevAnnotation -Question $team |
    Format-Table State, team -Wrap
```

`Select-Jev` keeps messages needing a reply. `Get-JevRanking` returns the three
most urgent of those messages. `Add-JevAnnotation` adds a `team` answer using
the billing, support, and sales choices defined in the script.

Illustrative output; live judgments and ordering can vary:

```text
State                                                     team
-----                                                     ----
Checkout is down. No customers can place orders.           support
Our event starts in two hours and tickets will not download. support
I was charged twice. Please refund the duplicate.          billing
```

If four messages pass selection, the pipeline makes twelve live requests:
five to select, four to rank, and three to annotate. Replace `Format-Table`
with `Export-Csv` or another PowerShell command to use the resulting objects.

## Find the checkout cause

The sample [checkout log](checkout.log) contains sixteen entries: normal activity,
unrelated errors, repeated checkout failures, and a payment API key that expired.
Run:

```powershell
./Examples/Pipelines/FindCheckoutCause.ps1
```

The entire search is:

```powershell
Get-Content ./Examples/Pipelines/checkout.log |
    Find-Jev 'Which entry best explains why customers cannot complete checkout?'
```

Illustrative output; live judgments can vary:

```text
2026-10-03T09:00:16Z ERROR payments: authorization rejected with HTTP 401; configured API key expired at 09:00:00Z. All payment attempts are being rejected.
```

The failed orders are symptoms. The payment entry supplies a likely explanation
for those failures. Other errors concern thumbnails, a newsletter, and a sales
export. `Find-Jev` compares all candidates together in one Choice request,
then returns the exact original line selected by Jev.

To explore the same data, change the question:

```powershell
Get-Content ./Examples/Pipelines/checkout.log |
    Find-Jev 'Which entry explains why the sales export failed?'

Get-Content ./Examples/Pipelines/checkout.log |
    Find-Jev 'Which entry reports a disk running out of space?'
```

The export question should find the locked-file entry. The disk question should
produce no output because the log supplies no matching evidence. Those are
model judgments, not guaranteed outcomes or proof that no disk issue exists.

`Find-Jev` accepts up to 254 input candidates, reserving one choice for none fits.
It returns at most one original input and has no confidence cutoff. Empty input
makes no request; API failures and malformed answers remain errors. For objects,
the candidates are represented as JSON and the selected original object comes
back with its properties and type intact. Narrow larger inputs before searching;
the command does not split them into batches.

## Tag an inbox

A Choice question picks one label. Tagging asks which labels apply independently,
so a message about a duplicate charge, a broken sign-in, and tonight's event can
be billing, account access, and urgent at once.

Run the eighteen-message demo:

```powershell
./Examples/Pipelines/TagInbox.ps1
```

Edit [inbox.json](inbox.json) to try your own messages. The script defines six
tags: billing, account access, delivery, product issues, urgency, and praise.
It includes overlapping problems, resolved issues, positive feedback, and
ordinary questions or feature requests that may match no tags.

The central call is:

```powershell
$results = @($messages | Add-JevTag $tags -Threshold 0.8)
```

Illustrative output; live tags can vary:

```text
Id      Tags                                      Subject
--      ----                                      -------
MAIL-01 billing, account_access, product_issue, urgent Double charge and locked out before tonight's event
MAIL-02 praise                                    Everything works now, thank you
MAIL-03 (none)                                    Do you ship to Canada?
MAIL-04 delivery, urgent                          Delivered on paper, missing before tonight's launch
MAIL-16 billing, account_access, product_issue    Charged twice and account recovery is broken
```

The sample uses a `0.8` cutoff; the command defaults to `0.5`. An absent tag
missed the cutoff, including uncertain cases. `Tags` is always a string array,
even with zero or one match. Each tag's probability is also a named property,
and full answers remain under `answers`. If the input already has a `Tags`
property, the new one is named `Jev_Tags`, with further prefixes if needed.
Original inputs are not modified.

All six questions share each message's request: eighteen messages make eighteen
requests, rather than 108. After that, ordinary PowerShell works on the saved
results without further Jev calls:

```powershell
# Messages can contribute to several counts, so totals may exceed inbox size.
$results | ForEach-Object Tags | Group-Object -NoElement |
    Sort-Object Count -Descending

# Build a worklist from the tags already returned.
$results | Where-Object { $_.Tags -contains 'urgent' -and $_.Tags.Count -gt 1 } |
    Select-Object Id, Subject, Tags
```

To inspect an uncertain result, look at its individual probabilities or full
`answers` property. Tagging and Choice answer different questions: use Choice
when exactly one label is needed, and tags when several can be true together.

## Route requests

Jev picks a team from the labels you supply. PowerShell maps that team to a
queue. Run:

```powershell
./Examples/Pipelines/RouteRequests.ps1
```

The compact call uses separate trailing arguments, with no commas:

```powershell
$team = $request |
    Get-JevChoice 'Which team owns this request?' billing shipping account other

$queue = switch ($team) {
    billing  { 'payments' }
    shipping { 'logistics' }
    account  { 'identity' }
    other    { 'triage' }
}
```

The script contains eight requests spanning duplicate charges, a delayed order,
broken account access, and requests outside those three teams. It prints a
routing worklist without changing any external system.

Illustrative output; live choices can vary:

```text
Id     Team     Queue     Message
--     ----     -----     -------
REQ-01 billing  payments  I was charged twice. Please refund the duplicate payment.
REQ-02 shipping logistics My order has not arrived and tracking has not changed in a week.
REQ-03 account  identity  I cannot sign in and every password reset link has expired.
REQ-04 other    triage    Could you consider adding dark mode in a future release?
```

Each request makes one Choice call and returns one label as a string. This
differs from tagging, where several independent labels may apply. The command
accepts one to 255 unique labels and uses each label as its description. Quote
multi-word labels, such as `'account access'`. Named array input is also supported:

```powershell
$request | Get-JevChoice -Question 'Which team owns this request?' `
    -Choices @('billing', 'shipping', 'account', 'other')
```

No confidence threshold or automatic fallback is applied. Include an `other`
or `unclear` option when useful. API failures, missing answers, and unknown
labels remain errors. Use a full Choice question with `Invoke-Jev` when you need
criterion descriptions, probabilities, or confidence details.

## Score requests

Define an ordered urgency scale, let Jev score each message, and use PowerShell
to label and sort the results. Capture the returned objects as an array:

```powershell
$results = @(./Examples/Pipelines/ScoreRequests.ps1)
$results | Format-Table Urgency, UrgencyLabel, Message -Wrap
```

The compact call uses quoted level descriptions as trailing arguments:

```powershell
$message |
    Get-JevScore 'How urgent is this?' 'Can wait' 'Needs attention soon' 'Needs attention now'
```

The levels map to `0`, `1`, and `2` in that order. Jev's score can fall between
levels, so `1.9` is near "Needs attention now". This is a weighted rating on
your scale, not a yes probability or confidence percentage.

The script adds a label alongside each score and message, then sorts locally:

```powershell
$scored = foreach ($message in $messages) {
    $urgency = $message |
        Get-JevScore 'How urgent is this?' 'Can wait' 'Needs attention soon' 'Needs attention now'

    [pscustomobject]@{
        Urgency = $urgency
        UrgencyLabel = switch ($urgency) {
            { $_ -ge 1.5 } { 'Needs attention now'; break }
            { $_ -ge 0.5 } { 'Needs attention soon'; break }
            default        { 'Can wait' }
        }
        Message = $message
    }
}

$scored | Sort-Object Urgency -Descending
```

The twelve messages include an outage, an event deadline, a workaround, routine
questions, and a resolved issue. Each makes one request; sorting makes none.
The `UrgencyLabel` property names the nearest level: scores below `0.5`
show "Can wait", scores from `0.5` to below `1.5` show "Needs attention soon",
and scores from `1.5` show "Needs attention now". These are display cutoffs you
can change; the original numeric scores still determine the sorting order.
The script returns objects with `Urgency`, `UrgencyLabel`, and `Message`
properties. Formatting is up to the caller. For example, use the saved array
to build a worklist without additional Jev calls:

```powershell
$results | Where-Object UrgencyLabel -eq 'Needs attention now'
$results | Export-Csv ./scored-requests.csv -NoTypeInformation
```

Unlike `Get-JevRanking`, this command exposes the numeric rating and lets you
define a multi-level rubric. It does not sort, round, or filter the scores.

The command accepts two to ten non-empty level descriptions. For named input:

```powershell
Get-JevScore -State $message -Question 'How urgent is this?' `
    -Levels @('Can wait', 'Needs attention soon', 'Needs attention now')
```

It returns a Double per input, in input order. Missing, invalid, or out-of-range
scores and request failures remain errors. Use a full Score question with
`Invoke-Jev` when you need confidence and probability distributions.
