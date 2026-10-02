# Log root-cause reranking

This small demo shows reranking on a familiar task: a service failed to start, and the log contains both useful evidence and distracting noise.

Run `Rank-StartupLogCandidates.ps1` with PowerShell 7 and the Jev module available in the repository. Set `TYPESAFE_API_KEY` first; this example makes one live Jev request.

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./Rank-StartupLogCandidates.ps1
```

The script reads each log line once. In that pass, it makes the line a candidate, adds it to the shared incident context, and creates a bounded Score question for it: how strongly does this candidate explain the startup failure? All candidate questions go in one `Invoke-Jev` call. PowerShell sorts the returned scores so the strongest explanations appear first.

That ordering is the reranking: the log lines already exist, and the script is not generating or changing them. Jev evaluates each line against the same question; PowerShell reorders the candidates by score, using confidence only to break ties. With three criteria, the score runs from 0 to 2 and can be fractional because it is a position on a scale, not a category number. The criteria anchor the scale at unrelated/routine, related symptom or context, and direct evidence of a cause. Confidence is Jev's separate confidence in its score; it is not added to or multiplied by the score.

The log is designed so the old database credential is the likely initiating cause. Repeated authentication failures and the failed startup check are strong evidence or downstream symptoms; normal startup messages and the optional telemetry warning are distractors. The result is a useful investigation lead, not proof. An engineer should verify the secret version and the deployment history before acting.

This differs from a keyword filter: a filter can find entries containing `database` or `password`, but it will not necessarily distinguish the stale credential clue from repeated failure symptoms, or rank either against routine entries. The bounded score makes the comparison explicit and keeps the final ordering in ordinary PowerShell.
