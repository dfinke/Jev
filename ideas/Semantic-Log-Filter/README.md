# Semantic log filtering: `-match` vs Jev

This demo explores a fixed keyword search and a fuzzy decision over the same small set of log entries. Run each filter on its own so you can inspect what it does before comparing the results. The regex looks for the whole words `disk`, `space`, or `quota`. The Jev question asks whether the entry describes storage capacity causing or likely to cause a failure.

See [Walkthrough.md](Walkthrough.md) for the sample log and separate PowerShell snippets for each approach.

The fixture includes different wording for similar problems (`ENOSPC`, `out of storage`, and `target drive full`), plus harmless mentions of a disk check, a quota policy, and a disk-space report. The expected labels in the script are hand-set for discussion; Jev results can vary.

## Run the keyword filter

This runs locally and does not call Jev:

```powershell
./Regex-LogFilter.ps1
```

It should find the explicit `No space left on device` line, but miss `ENOSPC`, the nearly full volume, the tablespace failure, and the full backup target. It also matches harmless mentions such as a passed disk check, a quota policy update, and a disk-space report.

## Run the semantic filter

Set a TypeSafe API key, then run the live Jev example:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./Semantic-LogFilter.ps1
```

This makes one live Jev request per log line: 12 requests for the included fixture. It does not mock results, and it does not perform remediation.

## Run both and compare

The comparison script runs the regex pass and then the live Jev pass on the same fixture. It displays the results side by side and summarizes false positives, misses, and Jev's `Review` cases against the hand-labeled fixture.

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./Compare-LogFilters.ps1
```

This also makes 12 live Jev requests. `Regex-LogFilter.ps1` and `Semantic-LogFilter.ps1` remain independently runnable; the comparison script uses their `-PassThru` output to analyze aligned result objects.

For a compact comparison with the sample log embedded in the script, run [Compare-LogFilters-Table.ps1](Compare-LogFilters-Table.ps1). It groups rows as both flagged, semantic only, regex only, and neither. A green `✓` means a filter flagged the line; a red `✗` means it did not. The marks show detections, not correctness. It makes 12 live Jev requests.

## What to compare

Jev evaluates the meaning of each line and returns a Noul probability for `diskIssue`.

The merged Jev result exposes that probability as `$decision.diskIssue`; the full typed answer remains available at `$decision.answers.diskIssue`. The sample labels results at `0.8` or above as `Storage issue`, at `0.2` or below as `No storage issue`, and the middle range as `Review`. Those are demonstration thresholds chosen by the script, not Jev defaults or guarantees.

The point is not that semantic classification replaces every regex. Use fixed patterns where the format is known; consider Jev when equivalent signals arrive in varied wording. Keep the decision policy in PowerShell, and keep human review for uncertain or consequential cases.
