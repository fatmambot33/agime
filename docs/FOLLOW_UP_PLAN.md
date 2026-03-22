# Follow-up Evolution Plan

Date: 2026-03-22

## Goal
Transform the repo from a practical setup script collection into a maintainable, testable, and safer deployment toolkit.

---

## Phase 1 — Baseline reliability (1-2 weeks)

### Outcomes
- Standardized docs and contribution flow
- Basic script quality checks in CI/local
- Repeatable verification path for contributors

### Tasks
1. Add shell quality tooling
   - Introduce `shellcheck` and `shfmt` guidance in docs.
   - Add a `Makefile` target (`lint`, `fmt-check`, `check`).
2. Add script syntax checks
   - Enforce `sh -n build.sh build-interactive.sh` in checks.
3. Add a minimal changelog policy
   - Create `CHANGELOG.md` and document update expectations.
4. Expand README operational sections
   - Prereqs, known limitations, post-deploy checks, and uninstall notes.

### Exit criteria
- New contributors can run a single command to execute all checks.
- Docs are sufficient for first-time deployment without external context.

---

## Phase 2 — Modularity and testability (2-4 weeks)

### Outcomes
- Reduced complexity in core setup logic
- Basic automated confidence for critical flows

### Tasks
1. Refactor `build.sh` into composable functions/files
   - Separate concerns: prerequisites, Traefik, OpenClaw, endpoint wiring.
2. Add dry-run mode
   - `DRY_RUN=1` prints planned changes without applying them.
3. Add idempotency checks
   - Validate repeated runs do not break existing installations.
4. Introduce smoke tests
   - Use containerized test harness (or Bats) for non-destructive validation.

### Exit criteria
- Core script can be exercised in dry-run mode in CI.
- At least one automated smoke scenario passes consistently.

---

## Phase 3 — Security + operations hardening (2-3 weeks)

### Outcomes
- Better secret handling and operational resilience
- Clear incident/runbook guidance

### Tasks
1. Secret handling improvements
   - Document secure env injection patterns.
   - Reduce secret exposure in logs/output.
2. Operational runbooks
   - Add troubleshoot, backup, restore, and rollback docs.
3. Pinning and compatibility policy
   - Document supported Docker/Traefik/OpenClaw version ranges.
4. Release process
   - Add release checklist and version-tagging workflow.

### Exit criteria
- Security-sensitive behavior is documented and reviewed.
- Operators have documented recovery steps for common failures.

---

## Prioritized backlog (next 5 items)

1. Add `docs/OPERATIONS.md` with troubleshooting + rollback.
2. Add `Makefile` with `check`, `lint`, and `fmt-check`.
3. Implement `DRY_RUN=1` path in `build.sh`.
4. Add GitHub Actions workflow for shell checks.
5. Split `build.sh` into logical modules (or sourced helper script).
