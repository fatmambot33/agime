# Follow-up Evolution Plan

Date: 2026-03-30

## Goal
Keep the refactored toolkit small, auditable, and private-by-default while expanding deterministic coverage.

## Completed in this refactor

- Reduced top-level operational surface to six explicit entrypoints.
- Removed legacy wrappers/flows that duplicated responsibilities.
- Simplified sync/setup to a clear local-sync then remote-apply model.
- Re-aligned docs to match the refactored runtime paths.
- Replaced sprawling test matrix with deterministic smoke/idempotency/hermetic checks.
- Added CI workflow for syntax, lint/format, smoke, and idempotency enforcement.

## Next priorities

1. Add hermetic failure tests for `build.sh` public-mode preflight validation.
2. Add finer-grained unit-like checks for template rendering in `scripts/build_lib.sh`.
3. Add release tagging checklist and changelog policy.
4. Add shell performance guardrails for large sync payloads.
5. Expand docs with operator troubleshooting decision trees.

## Why priorities changed

The repository was intentionally redesigned around fewer scripts and fewer modes. Priorities now focus on proving correctness and operability of the simpler model rather than extending legacy pathways.
