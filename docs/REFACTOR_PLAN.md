# Refactor Analysis + Plan

Date: 2026-03-30

## 1) Current-state analysis

The repository is now much smaller and easier to follow than before, but there is still structural overlap that should be cleaned up in a staged way.

### What is already good

- Top-level operational surface is constrained to six scripts: `build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`.
- Access modes are explicitly narrowed to `ssh-tunnel` (default) and `public`.
- Runtime logic is split between deploy modules (`scripts/build_lib.sh`, `scripts/build_steps.sh`) and orchestration modules (`scripts/lib/*.sh`).
- Deterministic test and CI gates exist (`make check-strict`, GitHub workflow).

### Remaining issues

1. **Module shape inconsistency**
   - Deploy internals use `scripts/build_*` while orchestration internals use `scripts/lib/*`.
   - This split is understandable but still inconsistent from a contributor perspective.

2. **`sync.sh` scope creep risk**
   - `sync.sh` currently handles config loading, uploading, and remote execution orchestration.
   - We should keep it intentionally narrow and avoid reintroducing policy complexity there.

3. **Docs are accurate but thin for contributors**
   - Operator docs are concise, but contributor docs need a stronger “what goes where” decision framework.

4. **Test coverage depth**
   - Current tests are good guardrails, but we still lack focused branch tests for public-mode failure scenarios and render-specific behaviors.

## 2) Keep / merge / rewrite / remove decisions

## Keep

- `build.sh` + `scripts/build_lib.sh` + `scripts/build_steps.sh` as the primary deploy engine.
- `sync.sh` as local-to-remote convenience workflow (secondary to env-driven remote execution).
- `backup.sh`, `restore.sh`, `update.sh` as first-class operations.
- Templates-only boundary under `templates/`.

## Merge (planned)

- Merge shared low-level helpers into a single stable helper surface in `scripts/lib/common.sh` and remove duplicated path/validation helpers across modules.

## Rewrite (planned)

- Rewrite contributor docs to include a strict ownership map:
  - top-level entrypoints = orchestration only
  - `scripts/build_*` = deploy engine
  - `scripts/lib/*` = reusable orchestration primitives
  - `templates/*` = render inputs only
  - `tests/*` = deterministic behavior checks

## Remove / avoid reintroducing

- Legacy wrapper entrypoints that duplicate behavior.
- Interactive-first flows in setup paths.
- Optional tooling installers in runtime deploy path.
- Any additional access modes beyond `ssh-tunnel` and `public`.

## 3) Target architecture (stable end-state)

- Top-level entrypoints (fixed set):
  - `build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`
- `scripts/build_*`:
  - deploy-specific defaults, rendering, docker apply, post-checks.
- `scripts/lib/*`:
  - shared orchestration helpers used by entrypoints.
- `templates/*`:
  - compose/json/dockerfile templates only.
- `tests/*`:
  - smoke + idempotency + hermetic + failure-path + security checks.
- `docs/*`:
  - operator and contributor guidance; no stale review snapshots.

## 4) Phased implementation plan

### Phase 1 (completed)

- Lock the six-entrypoint contract.
- Introduce `scripts/lib/*` modules for orchestration reuse.
- Add deterministic CI gate around `make check-strict`.

### Phase 2 (implemented in this cycle)

- Added branch-level tests for:
  - public-mode preflight validation failures,
  - sync env-file edge cases,
  - template-render substitution correctness.
- Added contributor-facing architecture map and decision checklist.

### Phase 3 (next)

- Normalize helper usage to reduce cross-module duplication.
- Add explicit deprecation notes for any remaining compatibility shims.

### Phase 4 (next)

- Release engineering hardening:
  - lightweight versioning policy,
  - release checklist,
  - compatibility/testing matrix policy.

## 5) Acceptance criteria per phase

- **Phase 2 done when:** new failure/branch tests are present and enforced by `make check-strict`.
- **Phase 3 done when:** helper duplication is measurably reduced and documented.
- **Phase 4 done when:** release process is fully documented and repeatable.

## 6) Non-goals

- Re-expanding modes/features that increase operator ambiguity.
- Reintroducing monolithic scripts or sprawling helper entrypoints.
- Prioritizing backward compatibility over clarity when old behavior is confusing.
