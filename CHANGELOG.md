# Changelog

All notable changes to Jev are documented here.

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
