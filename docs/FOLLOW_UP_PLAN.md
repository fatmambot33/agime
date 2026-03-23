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
- Split `build.sh` into sourced modules (`scripts/build_lib.sh`, `scripts/build_steps.sh`) to reduce core script complexity.
- Added deterministic dry-run idempotency test script (`tests/idempotency_dry_run.sh`) to assert stable repeated output.
- Added CI/local idempotency validation through `make idempotency`.
- Added deterministic security template checks (`tests/security_template_checks.sh`) and CI coverage via `make security`.
- Added cron-installable OpenClaw security audit runner (`scripts/run_security_audit.sh`, `scripts/install_security_audit_cron.sh`) with daily scheduling support.

---

## Phase 2 — Modularity and testability (2-4 weeks)

### Outcomes
- Reduced complexity in core setup logic.
- Basic automated confidence for critical flows.

### Tasks
1. Add idempotency checks
   - Validate repeated runs do not break existing installations.
2. Introduce smoke tests
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

1. Document version compatibility matrix for Docker/Traefik/OpenClaw.
2. Add module-level unit-style tests for template renderer and env validation helpers.
3. Add failure-injection scenarios for common operator mistakes (DNS mismatch, missing env, Docker access).
4. Add CI scenario for non-root user ownership and permission checks.
5. Add release checklist and version-tagging workflow.
