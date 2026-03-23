# Follow-up Evolution Plan

Date: 2026-03-22
Last Updated: 2026-03-23

## Goal
Transform the repo from a practical setup script collection into a maintainable, testable, and safer deployment toolkit.

---

## Completed this cycle

- Added shell quality tooling guidance and executable checks via `Makefile`.
- Enforced script syntax checks through `make check` (`sh -n build.sh build-interactive.sh sync.sh`).
- Added minimal changelog policy with `CHANGELOG.md` and contribution requirements.
- Expanded README with prerequisites, known limitations, post-deploy checks, and uninstall notes.
- Added `docs/OPERATIONS.md` with troubleshooting, backup, restore, and rollback guidance.
- Added GitHub Actions workflow for shell checks.
- Implemented `DRY_RUN=1` path in `build.sh` and exposed it through `build-interactive.sh`.
- Added deterministic dry-run smoke test script (`tests/smoke_dry_run.sh`).
- Added CI/local dry-run validation through the `make smoke` check.

---

## Phase 2 — Modularity and testability (2-4 weeks)

### Outcomes
- Reduced complexity in core setup logic.
- Basic automated confidence for critical flows.

### Tasks
1. Refactor `build.sh` into composable functions/files
   - Separate concerns: prerequisites, Traefik, OpenClaw, endpoint wiring.
2. Add idempotency checks
   - Validate repeated runs do not break existing installations.
3. Introduce smoke tests
   - Use containerized test harness (or Bats) for non-destructive validation.

### Exit criteria
- Core script can be exercised in dry-run mode in CI.
- At least one automated smoke scenario passes consistently.

---

## Phase 3 — Security + operations hardening (2-3 weeks)

### Outcomes
- Better secret handling and operational resilience.
- Clear incident/runbook guidance.

### Tasks
1. Secret handling improvements
   - Document secure env injection patterns.
   - Reduce secret exposure in logs/output.
2. Pinning and compatibility policy
   - Document supported Docker/Traefik/OpenClaw version ranges.
3. Release process
   - Add release checklist and version-tagging workflow.

### Exit criteria
- Security-sensitive behavior is documented and reviewed.
- Operators have documented recovery steps for common failures.

---

## Prioritized backlog (next 5 items)

1. Split `build.sh` into logical modules (or sourced helper script).
2. Add idempotency validation checks for repeat runs.
3. Document version compatibility matrix for Docker/Traefik/OpenClaw.
4. Add module-level unit-style tests for template renderer and env validation helpers.
5. Add failure-injection scenarios for common operator mistakes (DNS mismatch, missing env, Docker access).
