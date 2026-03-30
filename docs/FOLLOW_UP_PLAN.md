# Follow-up Evolution Plan

Date: 2026-03-30

## Goal
Keep the toolkit minimal, auditable, and private-by-default while improving test depth in small phases.

## Refactor phases

### Phase 1 (implemented)

- Lock top-level contract to six entrypoints.
- Extract orchestration concerns into `scripts/lib/` modules (`common`, `sync`, `setup`, `update`).
- Keep `build.sh` as primary deploy engine with existing `scripts/build_*` modules.
- Standardize deterministic checks in local `make` and CI.

### Phase 2 (implemented in this cycle)

- Added public-mode preflight and sync env edge-case coverage.
- Added template render substitution tests and contributor architecture checklist.

### Phase 3 (implemented in this cycle)

- Added shared helper normalization and deprecation documentation for compatibility shims.

### Phase 4 (implemented in this cycle)

- Added release process docs (tagging, changelog cadence, compatibility policy).
- Added release-policy doc checks to `make check-strict`.

## Next priority

- Add troubleshooting runbooks and operational diagnostics.

## Why this phased approach

The previous one-shot rewrite was too abrupt. This plan keeps the simplified architecture but introduces it incrementally with stronger guardrails and test-backed milestones.

See also: `docs/REFACTOR_PLAN.md` for detailed keep/merge/rewrite/remove analysis and phased execution checklist.
