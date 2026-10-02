# Estimate what a run cost

Jev returns token usage with each answer. This example adds up the reported input and output tokens and estimates a run's cost using prices you supply.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run the example using Jev's published rates by default: $0.042 per million input tokens and $0 per million output tokens.

```powershell
$run = .\Examples\Demos\28-what-a-run-cost\EstimateRunCost.ps1

$run.Rows | Format-Table Id, Specialist, InputTokens, OutputTokens, EstimatedUsd
$run.Summary | Format-List
```

The price parameters remain available if your pricing differs. For example, add `-InputPricePerMillionTokens 0.042 -OutputPricePerMillionTokens 0` to the script call to set them explicitly.

The sample file has three requests. The script makes one live Jev call for each and reads `usage.input_tokens` and `usage.output_tokens` from the merged response. It estimates each request and the total with this formula:

```text
(input tokens × input price + output tokens × output price) ÷ 1,000,000
```

The script uses those rates by default, so you can also run it without the price parameters. Jev's published pricing says output tokens are free; the parameters remain available for a different model or contract. Check [TypeSafe's model pricing](https://docs.typesafe.ai/models) for the current rates. If a response has no usage values, its ID appears in `MissingUsageIds` and its cost is left blank instead of silently counted as zero. The total includes only requests with reported usage, so check that list before treating the estimate as complete.

This is an estimate from reported token counts, not a provider invoice or a spending cap. Each run makes new live requests; no recordings or replay data are used.

