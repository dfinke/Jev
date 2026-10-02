# Azure Cost Recommendation Router

This small example shows one Jev classification becoming one readable PowerShell route. It uses five fictional Azure Advisor-style recommendations and does not connect to Azure or apply changes.

## What happens

The script reads `advisor-recommendations.csv` with `Import-Csv` and pipes each imported row directly to `Invoke-Jev`. It does not rebuild a row in a separate state variable. Each item has a recommendation, estimated monthly savings, environment, and a short workload-owner note.

Jev answers one bounded `Choice` question for each item:

- `cost_owner_review` — the workload owner should validate a plausible savings opportunity.
- `technical_review` — the note mentions production, capacity, customer impact, or dependencies that deserve a technical check first.
- `needs_context` — the environment, owner, or business context is unclear.

A PowerShell `switch` maps the selected category to a route and a short reason. For example, an underused development VM with a confirmed idle window goes to workload-owner review; a production database with unconfirmed peak capacity goes to technical review; a disk with no owner goes to gather context.

The `RouteReason` is written by PowerShell from the selected lane and its visible criteria. Jev returns a bounded classification and confidence; it does not generate a hidden chain of reasoning. A person reviews the recommendation before any Azure change.

## Run it

From the repository root, set `TYPESAFE_API_KEY` and run:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./ideas/Azure-Cost-Recommendation-Router/Invoke-AzureCostRecommendationRouter.ps1
```

The script sends one request per CSV row and writes `output/cost-recommendation-triage.csv` beside the script. Pass `-InputPath` to use another CSV with the same columns.

## Visual walkthrough

The [Wails visualizer](visualizer/README.md) animates the same CSV → Jev classification → PowerShell `switch` → review-lane flow. It is useful for showing how each recommendation moves through the pipeline; every row still makes a live Jev request.

## How it relates to real Azure work

Azure Advisor cost recommendations can be exported as CSV. In a real workflow, a team could add environment and owner context to that export, or join it from its inventory/tagging data. This sample keeps the enrichment step out of scope so the classification and route are easy to see.

- [Export cost recommendations from Azure Advisor](https://learn.microsoft.com/en-us/azure/advisor/advisor-how-to-calculate-total-cost-savings)
- [Azure Cost Management exports](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-export-acm-data)
