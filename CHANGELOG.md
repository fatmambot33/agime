# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Changed
- Refactored repository into a minimal six-entrypoint layout: `build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`.
- Simplified `sync.sh` to a clearer local-sync + remote-apply workflow.
- Simplified `setup.sh` into a non-interactive env-driven deploy wrapper.
- Simplified `update.sh` into explicit optional `git pull` + backup + build stages.
- Removed legacy top-level wrappers and stale docs that duplicated behavior.
- Rewrote docs for deployment, operations, contribution workflow, and roadmap alignment.
- Replaced sprawling test set with deterministic smoke/idempotency/hermetic coverage.
- Added GitHub Actions CI (`.github/workflows/ci.yml`) to enforce syntax, lint/format, and core test checks.
