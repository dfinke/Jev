
# Comparing a keyword match with a semantic log filter

Both examples use the same log lines. The keyword filter checks for specific words. The Jev filter asks whether each line describes a storage-capacity problem, even when the wording changes.

## Sample log

```text
2026-09-27 06:01:12 INFO  Service started on port 8080
2026-09-27 06:02:45 INFO  Nightly disk check passed
2026-09-27 06:03:10 WARN  Volume /var at 98% capacity
2026-09-27 06:04:22 ERROR write failed: ENOSPC
2026-09-27 06:05:01 INFO  User jsmith logged in
2026-09-27 06:05:33 ERROR No space left on device
2026-09-27 06:06:14 WARN  Temp directory quota policy updated
2026-09-27 06:07:48 ERROR Cannot extend tablespace USERS: out of storage
2026-09-27 06:08:02 INFO  Cache cleared, 0 items removed
2026-09-27 06:09:19 WARN  Backup job skipped: target drive full
2026-09-27 06:10:05 ERROR Connection to db01 timed out
2026-09-27 06:11:30 INFO  Disk space report emailed to ops
```

Load the lines once. Each filter below can run on its own with this input:

```powershell
$logLines = Get-Content -LiteralPath .\app.log
```

## The keyword match

This pattern looks for the whole words `disk`, `space`, or `quota`:

```powershell
$pattern = '\b(disk|space|quota)\b'
$regexHits = $logLines | Where-Object { $_ -match $pattern }
$regexHits
```

It matches these four lines:

```text
2026-09-27 06:02:45 INFO  Nightly disk check passed
2026-09-27 06:05:33 ERROR No space left on device
2026-09-27 06:06:14 WARN  Temp directory quota policy updated
2026-09-27 06:11:30 INFO  Disk space report emailed to ops
```

The match catches harmless mentions in the disk check, quota update, and report. It misses four expected storage issues because they use different wording: the volume at 98%, `ENOSPC`, the full tablespace, and the full backup target.

## The semantic filter

The question defines the condition Jev should evaluate. Noul returns a probability that the `true` criterion applies. PowerShell then maps that value to a result label:

```powershell
$question = New-JevQuestion -Name diskIssue -Type Noul `
    -Instructions 'Does this log entry indicate that a storage volume, filesystem, or database tablespace is full or close to full, causing writes or backups to fail?' `
    -Criteria @{
        true  = 'Storage capacity is exhausted or nearly exhausted and is causing, or is likely to cause, failed writes or backups.'
        false = 'The entry only mentions disks, space, or quotas without indicating a storage capacity problem.'
    }

$logLines |
    Invoke-Jev -Question $question |
    Select-Object State, @{
        Name       = 'Probability'
        Expression = { [math]::Round([double] $_.diskIssue, 2) }
    }, @{
        Name       = 'Assessment'
        Expression = {
            if ($_.diskIssue -ge 0.8) { 'Storage issue' }
            elseif ($_.diskIssue -le 0.2) { 'No storage issue' }
            else { 'Review' }
        }
    }
```

The `0.8` and `0.2` cutoffs are example PowerShell policy, not Jev defaults. Values in between become `Review`. The numbers come from live Jev responses, so this walkthrough does not invent fixed scores or promise that every line will receive a particular probability.

## Why the results differ

`-match` can only find the words in its pattern. Jev evaluates the condition described in the question, so it can recognize related wording such as `ENOSPC` or `target drive full` without those exact terms appearing in the pattern. The question and criteria matter: Jev is not guessing what “bad” means.

The boundary still belongs to PowerShell. The script chooses what to do with a high, low, or uncertain probability; the demo only displays the assessment and does not alert anyone or change a system. Use exact patterns for known formats, and consider a semantic filter when the same signal arrives in varied wording.
