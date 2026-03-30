# Deprecations

Date: 2026-03-30

This file tracks compatibility shims that remain temporarily supported while the repository completes refactoring phases.

## Active shims

### `SYNC_REMOTE_ENTRYPOINT=configure.sh` or `build-interactive.sh`

- Status: deprecated.
- Current behavior: `sync.sh` rewrites to `build.sh` and prints a warning.
- Migration: set `SYNC_REMOTE_ENTRYPOINT=build.sh` explicitly.

### `OPENCLAW_ACTION`

- Status: deprecated.
- Current behavior: ignored by `sync.sh` with warning.
- Migration: remove this variable from configs/scripts.

### `SYNC_REMOTE_CONFIG_PRIORITY`

- Status: deprecated.
- Current behavior: ignored by `sync.sh` with warning.
- Migration: remove this variable from configs/scripts.

## Removal policy

These shims should be removed after one release cycle once docs and runbooks no longer reference them.
