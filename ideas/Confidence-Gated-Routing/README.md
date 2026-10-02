# Confidence-gated routing

This example shows why a Jev answer and its confidence are separate inputs to a PowerShell decision. The same `Choice` answer can lead to different handling depending on the cost of being wrong.

The script classifies five fictional customer requests, then applies these illustrative policies:

| Requested action | Confidence bar | Suggested handling |
| --- | ---: | --- |
| Show a balance | 0.50 | Show the read-only information, or ask a person below the bar |
| Tag and route a ticket | 0.65 | Send it to a human support queue, or ask a person below the bar |
| Transfer money | 0.85 | Ask the customer to confirm; send lower-confidence cases to a person |
| Delete an account | Manual review | Never authorize an irreversible action from confidence alone |
| Unclear request | Clarify | Ask what the customer wants done |

These are demonstration thresholds, not universal recommendations. A real system should set and validate thresholds against its own outcomes and the consequences of mistakes. Jev classifies the intent; PowerShell owns the threshold policy and next-step routing.

## Run it

From the repository root, set `TYPESAFE_API_KEY` and run:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./ideas/Confidence-Gated-Routing/Invoke-ConfidenceGatedRouting.ps1
```

The script makes one live Jev request per customer message. It only prints suggested handling; it does not access accounts, route real tickets, transfer funds, or delete records.
