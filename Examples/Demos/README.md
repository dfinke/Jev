# Jev PowerShell demos

Each demo is a small, runnable example of using Jev from PowerShell. These PowerShell ports are inspired by the [ThinkThen demos](https://github.com/botassembly/thinkthen/tree/main/demos). The scripts use the Jev module, make live requests, and include sample input. Set `TYPESAFE_API_KEY` before running a demo. Start at the repository root unless its README says otherwise.

## Start with these

| # | Demo | What it shows |
|---|---|---|
| 01 | [Refund gate](01-refund-gate/README.md) | Pipe text into a small yes/no function and print a Boolean. |
| 02 | [Route a ticket](02-route-a-ticket/README.md) | Choose a category, apply a confidence threshold, and route it with `switch`. |
| 03 | [Grep for meaning](03-grep-for-meaning/README.md) | Keep issue reports by meaning rather than exact words. |
| 15 | [Find the line](15-find-the-line/README.md) | Choose the best matching line from a bounded document in one call. |
| PS | [Inline refund check](Inline-Refund-Check/README.md) | Use the pipeline-friendly `Test-Jev` command to return a Boolean. |
| PS | [Test a review stream](Pipelines/TestReviewStream.ps1) | Keep each review beside its Boolean complaint judgment as reusable PowerShell objects. |

## Gates and workflows

| # | Demo | What it shows |
|---|---|---|
| 16 | [Triage a support queue](16-triage-pipeline/README.md) | Ask several focused questions per ticket and apply a PowerShell policy. |
| 19 | [Fail closed on a proposed command](19-no-or-could-not-ask/README.md) | Hold a proposal when the answer is no, uncertain, or unavailable. |
| 21 | [Choose the next action from the record](21-options-from-the-record/README.md) | Let each workflow step supply its own set of possible actions. |
| PS | [Loan approval](Loan-Approval/README.md) | Read applications from CSV, create validated objects, and evaluate an editable Markdown policy. |

## Search, ranking, and cost

| # | Demo | What it shows |
|---|---|---|
| 06 | [Top search hits](06-top-search-hits/README.md) | Score every passage against a query and sort the best matches first. |
| 17 | [Rate and sort requests](17-rate-and-sort/README.md) | Score work on a named scale, then order a queue in PowerShell. |
| 28 | [What a run cost](28-what-a-run-cost/README.md) | Estimate cost from Jev's reported token usage. |

These examples use existing Jev module commands. They do not use recordings or replay data; results and confidence values can vary between live runs.
