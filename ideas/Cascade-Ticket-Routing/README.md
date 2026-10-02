# Jev-first ticket cascade

This example shows a practical cascade: use Jev to quickly classify each support request, let PowerShell handle the routine cases it can resolve from known facts, and send uncertain or high-impact cases to a person.

## The path

1. Read one ticket row from `support-tickets.csv`.
2. Send its message and available order facts to Jev with two questions in one request: the request intent (`Choice`) and whether it is high stakes (`Noul`).
3. Apply confidence and high-stakes thresholds in PowerShell.
4. Handle safe order-status and known duplicate-charge policy checks locally; route product issues to support; escalate high-stakes or low-confidence cases.

The confidence thresholds vary by route because the cost of a mistake varies. A read-only status lookup has a lower bar than giving a policy answer. Suspected unauthorized activity or a customer-impacting outage is escalated regardless of intent confidence. An unclear request is sent back for clarification.

The local handlers use only the supplied sample CSV facts and a simple stated policy rule. The script does not call an order system, change a ticket, issue a refund, or call a second language model. The escalated route is the handoff point where a real application could create a human review item or invoke a stronger reasoning model.

## Run it

From the repository root, set `TYPESAFE_API_KEY` and run:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./ideas/Cascade-Ticket-Routing/Invoke-CascadeTicketRouting.ps1
```

The script makes one live Jev request per row, with both questions included in that call. It writes `output/cascade-routing-results.csv` beside the script. Pass `-InputPath` to try another CSV with the same columns.

## Why this is a cascade

Jev decides which path fits and reports confidence. Most routine work can stay in predictable PowerShell code. Requests that are unclear, risky, or poorly classified leave the fast path for a person or a separately configured reasoning model. The split shown by this small sample is illustrative; measure real outcomes before choosing thresholds or estimating savings.
