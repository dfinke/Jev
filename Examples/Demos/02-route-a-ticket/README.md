# Route a ticket

A support ticket needs a destination. Ask Jev to choose a team from a small, defined set, then let PowerShell apply a confidence threshold and map the team to a queue.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\02-route-a-ticket\RouteTicket.ps1
```

The sample is a bounced renewal charge, so it should route to `payments`. The script displays the selected team, its probability, the threshold (`0.8` by default), and the resulting queue. If the leading category is below the threshold, it routes to `triage` for a person to review.

The question uses the four categories from the original demo: `billing`, `shipping`, `account`, and `other`. PowerShell maps those labels to `payments`, `logistics`, `identity`, and `triage`. Jev selects a label; the `switch` statement performs the routing.

The Rust demo also shows classifying a folder of notes. This first PowerShell port stays focused on routing one ticket so the choice and threshold are easy to follow.

Ported from `thinkthen/demos/02-route-a-ticket`, using the existing `New-JevQuestion` and `Invoke-Jev` commands. This example makes a live Jev request each time it runs.
