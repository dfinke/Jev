# Azure Tenant Portfolio Review

This is a small example of a cloud platform or FinOps team turning familiar Azure reports into a prioritized review queue. It does not connect to Azure or change tenant settings.

## The real-world pattern

Teams already review cloud cost, Azure Advisor recommendations, resource inventory, and Azure Policy compliance. Microsoft documents these as recurring parts of cost management and cloud governance. The underlying data is available through Cost Management exports, Advisor recommendation exports, Azure Policy compliance results, and Azure Resource Graph queries.

Those sources do not naturally arrive as one neat row per tenant. This sample represents a **normalized rollup** someone might build by joining exports and query results on subscription/resource identifiers and summarizing them. The data is fictional; the shape is grounded in the kinds of signals those reviews use.

The sample has objective signals such as monthly cost, potential Advisor savings, noncompliant resource count, tag coverage, subscription count, and snapshot age. It also has a short analyst note describing context that the metrics alone cannot explain.

## What Jev adds

The script asks three bounded questions for each tenant summary:

- **Workstream (`Choice`)** — cost optimization, governance follow-up, inventory cleanup, migration planning, integration planning, or monitor.
- **Needs discovery (`Noul`)** — whether key facts need confirmation before routing.
- **Urgency (`Score`)** — routine, soon, priority, or immediate.

PowerShell applies the routing gates: stale snapshots are refreshed first; uncertain classifications go to discovery; immediate work is expedited; otherwise the row joins the selected workstream. It exports the decisions, probabilities/confidence, route, and reason to a CSV for a person to review.

That’s the possibility this example demonstrates: use Jev for the fuzzy interpretation of mixed metrics and notes, then keep policy thresholds, routing, and reporting in readable PowerShell. It creates a first-pass queue for a periodic portfolio review; it does not claim to replace Azure’s native cost or governance tools.

## Run it

The included `tenant-inventory.csv` contains only fictional data. From the repository root, set `TYPESAFE_API_KEY` and run:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./ideas/Azure-Tenant-Portfolio/Invoke-AzureTenantPortfolioReview.ps1
```

The script evaluates each tenant row in one Jev request with all three questions and writes `output/tenant-triage-results.csv` beside the script.

To check the PowerShell flow and CSV output without an API call:

```powershell
./ideas/Azure-Tenant-Portfolio/Invoke-AzureTenantPortfolioReview.ps1 -Mock
```

Mock mode only checks the script and export path; its canned answers do not represent Jev classifications.

## Input fields

| Column | Example source in a real workflow |
| --- | --- |
| `TenantName`, `SubscriptionCount` | Portfolio or subscription inventory |
| `MonthlyCostUsd` | Cost Management cost export, rolled up by tenant/client |
| `AdvisorCostRecommendationCount`, `PotentialMonthlySavingsUsd` | Azure Advisor cost recommendations export |
| `NonCompliantResources` | Azure Policy compliance results, summarized by tenant/client |
| `UntaggedResourcePercent` | Resource inventory/Resource Graph query, summarized by tenant/client |
| `SnapshotAgeDays` | Calculated from each source extract’s timestamp |
| `ContextNotes` | Short analyst or account-team context |

These are example inputs, not a prescribed Azure assessment schema. Join keys, currency, date windows, compliance policy scope, and stale-data rules need to be defined for the real environment. The script’s gates (60 days for snapshot age, 0.75 for discovery probability, and 0.60 for Choice confidence) are illustrative values, not Microsoft recommendations.

## Relevant Microsoft references

- [Azure Resource Graph overview](https://learn.microsoft.com/en-us/azure/governance/resource-graph/overview)
- [Azure Policy compliance data](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data)
- [Export Azure Cost Management data](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-export-acm-data)
- [Export Azure Advisor cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-how-to-calculate-total-cost-savings)
- [Azure governance design area](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/governance)
