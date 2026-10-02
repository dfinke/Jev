# Grep for meaning

`Select-String` finds words. This example keeps issue reports that explain how to reproduce a defect, even when their wording differs.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\03-grep-for-meaning\Find-ReproducibleIssues.ps1 |
    Select-Object id, body
```

The sample CSV has five synthetic reports. Two describe repeatable failures with concrete steps; the feature request, vague performance complaint, and how-to question do not. The script asks Jev one Noul question per row and keeps reports whose yes probability is at least `0.9`.

The request includes only each row's `body`. The returned PowerShell object is the original row, so its `id`, `opened` date, and `reporter` remain available to later commands without sending those fields to Jev.

Change the input file with `-Path`, or adjust the cutoff with `-Threshold 0.8`. Each row makes a live Jev request; results may differ from the illustrative two matches.

Ported from `thinkthen/demos/03-grep-for-meaning`, using the existing `New-JevQuestion` and `Invoke-Jev` commands. No recording or replay data is used.
