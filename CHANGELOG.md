# Changelog

All notable changes to this repository are documented in this file.

The format is inspired by Keep a Changelog and this project follows a simple date-based release cadence.

## [Unreleased]

### Added
- Added quality gate tooling via `Makefile` (`check`, `lint`, `fmt-check`) and CI shell workflow.
- Added operator runbook in `docs/OPERATIONS.md`.
- Expanded README with prerequisites, limitations, post-deploy validation, and uninstall notes.

### Changed
- Updated contribution guidance to require changelog updates and standardized local checks.
- Updated roadmap status to remove completed follow-up items from the prioritized backlog.
- Added explicit reinstall procedure to README and operations runbook.
- Added `DRY_RUN=1` planning mode to `build.sh` and exposed the option in `build-interactive.sh`.
- Fixed generated Docker Compose YAML indentation in `build.sh` so services parse correctly.
