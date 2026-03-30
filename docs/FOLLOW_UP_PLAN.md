# Follow-up Plan

Date: 2026-03-30

## Current state

The refactor is complete: the repository now follows the six-entrypoint architecture with modular script internals, deterministic tests, and CI validation.

## Next work (post-refactor)

1. Add troubleshooting runbooks for common deployment failures.
2. Add operator diagnostics cheatsheet (`docker logs`, health probes, TLS checks).
3. Add release examples and tagging automation snippets.

## Guardrails to keep

- Keep exactly two access modes: `ssh-tunnel` (default) and `public`.
- Keep top-level entrypoints limited to `build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`.
- Keep behavior changes coupled with docs + hermetic test updates in the same PR.
