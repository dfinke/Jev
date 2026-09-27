# Changelog

All notable changes to Jev are documented here.

## [0.3.0] - 2026-09-26

### Added (Gemini Flash 3.8 (HIGH) + /skills)

- **Question Primitives**:
  - `New-JevChoiceQuestion` for typed Choice questions with automatic fallback (`-AllowOther`, `-FallbackDescription`).
  - `New-JevScoreQuestion` for ordered descriptive levels with normalization metadata (`MaxLevel`, `LevelCount`).
  - `New-JevCriterion` for contrastive structured criteria (`what`, `not_for`, `examples`).
  - `New-JevQuestionSet` to validate and assemble question batches for speculative fan-out.

- **Decision Analysis & Uncertainty Engine**:
  - `Get-JevConfidenceTier` evaluating decisions against the 3-tier behavioral model (`Act`, `Review`, `Escalate`) with risk-scaled thresholds (`Low`, `Standard`, `High`).
  - `Measure-JevScore` for normalized composite scoring across Noul/Score dimensions with hard policy overrides.
  - `Invoke-JevRerank` implementing the "Select instead of generate" / Reranking pattern.

- **PowerShell Pipeline & Array Extensions**:
  - `Where-Jev` for semantic, natural-language pipeline filtering.
  - `Select-JevRoute` for intent-based routing to scriptblocks.
  - Array script methods extended on `System.Array`: overloaded `.Jev()`, `.JevWhere()`, and `.JevRank()`.

- **Dynamic Mock & Fixture Subsystem**:
  - `Set-JevMockRule` and `Clear-JevMockRule` for custom offline unit testing without API keys.
  - `Export-JevFixture` and `Import-JevFixture` for recording live responses and replaying them offline in CI/CD.

- **New Workflows & Examples**:
  - `SpeculativeCustomerRouter.ps1` and `CandidateLogExtraction.ps1`.
- **Comprehensive Pester Tests**:
  - Added test suites for Questions, Composition, Pipeline, and Mock subsystems.

## [0.2.0] - 2026-09-24

### Added

- `Invoke-Jev -AsJson` to return the merged result as JSON text; combine with `-Raw` to serialize the raw Jev response.
- `New-JevYesNoQuestion` as a friendly way to create a Noul question with explicit true and false criteria.
- `.Jev()` on arrays to evaluate each record against a plain-language condition.
- A two-incident README demo that displays `page` or `do not page`, plus a fuller paging example with an uncertainty review outcome.
- Examples for deal decisions, Excel queues, notes, release notes, standups, and PowerShell command discovery.

### Documentation

- Clarified that Noul returns a probability and that the paging cutoff is an example policy.

## [0.1.0] - 2026-09-22

First preview release of the Jev PowerShell module.

### Added

- `Invoke-Jev` for sending structured questions and input to the Jev decision model.
- `New-JevQuestion` with Noul, Choice, and Score question types.
- Question parameters aligned with the Jev payload keys: `Name`, `Type`, `Instructions`, and `Criteria`.
- Retry, timeout, and mock support for the API client and its tests.
- QuickStart, refund triage, security incident, and semantic log triage examples.
- Pester tests, an MIT license, and helper scripts for local installation and Gallery publication.

### Changed

- `Invoke-Jev` documents `-State` as the input parameter, matching Jev's request payload. `-InputObject` remains available as a compatibility alias.
- `Invoke-Jev` now enriches pipeline output with the original state and Jev response details by default. Use `-Raw` for the unmodified Jev response.
- Named Jev answers are promoted to top-level properties in the merged output while the full `answers` object remains available.
