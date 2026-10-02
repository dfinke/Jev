# Triage a support queue

Jev answers focused questions about each ticket. PowerShell applies the policy: block credential requests, send uncertain, urgent, and out-of-scope tickets to review, and draft the routine ones.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\16-triage-pipeline\TriageTickets.ps1 |
    Format-Table Id, CredentialRequest, Queue, Urgency, Action, Reason
```

The CSV has six fictional tickets and contains only `id`, `subject`, and `body`. For each ticket, the script asks three questions together in one `Invoke-Jev` call, sending only `body`. The result table keeps the ticket ID and subject local.

The script makes the decision cutoffs explicit:

- Credential request probability at or above `0.8` means yes; at or below `0.2` means no; the middle band goes to review.
- A queue is accepted only when the selected category's probability is at least `0.8`; otherwise it is unsure and goes to review.
- Urgency is a score from 0 to 2. A score of `1` or higher goes to review.

The PowerShell policy runs in order: unsure answers go to review; credential requests are blocked; `other` requests go to review; urgent requests go to review; all remaining tickets are marked `draft`. These are labels for a demo—no email is sent, ticket is changed, or action is carried out.

Each ticket makes one live Jev request containing all three questions. The answers can vary between runs, and the thresholds are illustrative policy choices. This small example leaves out the Rust demo's recording, audit-file publishing, parallel jobs, and recovery machinery.

Ported from `thinkthen/demos/16-triage-pipeline`, using the existing `New-JevYesNoQuestion`, `New-JevQuestion`, and `Invoke-Jev` commands. No module changes or recording/replay data are used.
