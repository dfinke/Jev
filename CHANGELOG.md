# Changelog

All notable changes to Jev are documented here.

## [0.4.0] - 2026-10-03

### Added

- `Get-JevRanking` for semantic ranking by yes probability, returning original inputs with stable ties and an optional `-Top` limit.
- `Find-Jev` to compare up to 254 candidates in one Choice request and return the best original input, or nothing when none fits.
- `Add-JevTag` to evaluate independent labels in one request per input and add a thresholded `Tags` array alongside probabilities and response details.
- `Get-JevChoice` to return one label per input, accepting choices as separate trailing arguments without commas.
- `Get-JevScore` to return a weighted numeric score per input on two to ten ordered levels, accepting level descriptions as separate trailing arguments.
- `Examples/Pipelines/ScoreRequests.ps1` to score twelve customer messages and sort them by urgency using PowerShell.
- `Examples/Pipelines/RouteRequests.ps1` to classify eight requests and map each selected team to a queue with a PowerShell `switch`.
- `Examples/Pipelines/TagInbox.ps1` with eighteen sample messages, six overlapping tags, tag counts, and an urgent-message worklist.
- `Examples/Pipelines/FindCheckoutCause.ps1` and a sixteen-line checkout log showing a likely cause among symptoms and unrelated errors.
- A six-message ranking example in `Examples/Pipelines/RankReplies.ps1`.
- `Examples/Pipelines/PrioritizeInbox.ps1` to select messages needing a reply, rank the top three, and annotate the responsible team in one pipeline.
- Developer quick hits for finding and ranking build-log clues, selecting user-visible test failures, and routing test failures to a component.
- A loan approval walkthrough with CSV input, PowerShell-calculated percentages, and a human-editable Markdown policy, plus a review-stream example that returns reusable objects.

## [0.3.1] - 2026-10-03

### Added

- `Select-Jev` to keep original pipeline inputs that reach a yes/no probability threshold.
- `Add-JevAnnotation` to enrich pipeline inputs with named answers using `Invoke-Jev`.
- `Examples/Pipelines` with a reply-triage example that selects messages before annotating them.
- GitHub Actions workflow to validate the module manifest and run Pester tests on pushes, pull requests, and manual runs.

### Fixed

- `Test-Jev` binds the first positional argument to `Question` and the second to `Threshold`, leaving `State` for pipeline input or `-State`.

## [0.3.0] - 2026-10-02

### Added

- `Test-Jev` for pipeline-friendly yes/no checks that return a Boolean at a caller-selected probability threshold.
- Teaching-focused PowerShell demos ported from ThinkThen, with sample inputs and a categorized demos index.

### Documentation

- Documented `Test-Jev` behavior, thresholds, and per-input live requests.

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
