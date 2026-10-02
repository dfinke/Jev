# Find the line

When one short document contains several rules, ask Jev to select the line that best answers a question. This sends all candidate lines together in one request, so each line can affect the choice.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\15-find-the-line\FindPolicyLine.ps1
```

The sample policy has twelve lines. The default question should return:

```text
Refunds reach the original payment method within five working days.
```

The script uses the question as the state and the policy lines as the `Choice` criteria. Jev returns a short label such as `line07`; PowerShell maps that label back to the exact original line.

For a question the policy does not cover, include `-AllowNone`:

```powershell
.\Examples\Demos\15-find-the-line\FindPolicyLine.ps1 `
    -Question 'How long is the manufacturer warranty?' `
    -AllowNone
```

The extra choice lets Jev answer `none`; the script then prints `ask a person`. Without `-AllowNone`, Jev must select one of the policy lines, even when none is a good answer.

This differs from the previous reranking example: `RankSearchHits.ps1` makes one Jev request per candidate and sorts the scores in PowerShell. Here, all lines are options in one Choice question and Jev returns the selected label directly. Use this only for a bounded document whose full set of candidate lines fits in the request.

Ported from `thinkthen/demos/15-find-the-line`, using the existing `New-JevQuestion` and `Invoke-Jev` commands. This example makes one live Jev request each time it runs; no recording or replay data is used.
