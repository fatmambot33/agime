# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Changed
- Implemented refactor Phase 1 with modular orchestration libraries under `scripts/lib/`.
- Refactored `sync.sh`, `setup.sh`, and `update.sh` to source shared library modules.
- Added hermetic failure-path and template-security checks.
- Updated CI to run `make check-strict` as the single gate.
- Updated roadmap/docs to reflect phased delivery of the redesign.
