# Follow-up Evolution Plan

Date: 2026-03-22
Last Updated: 2026-03-25

## Goal
Transform the repo into a maintainable, testable, and secure deployment toolkit that defaults to private access.

## Completed this cycle

- Introduced explicit access-mode model via `OPENCLAW_ACCESS_MODE` with default `ssh-tunnel` and opt-in `public` mode.
- Split OpenClaw compose templates into public and ssh-tunnel variants.
- Added change-aware `openclaw:local` rebuild logic with revision stamp tracking.
- Hardened post-build validation for both modes (local health in ssh-tunnel, HTTPS/TLS retry logic in public).
- Updated interactive setup and docs to be mode-aware and private-by-default.
- Added optional Signal channel bootstrap (`OPENCLAW_ENABLE_SIGNAL`) with `signal-cli` dependency checks/auto-install and template-backed `channels.signal` rendering.
- Added backup/restore helper scripts with explicit safety guard for root-level restore operations.
- Integrated optional pre-deploy backups into the interactive setup flow so operators can checkpoint before changes.
- Fixed ownership correction flow so setup works for both root and non-root execution contexts (optional sudo usage).
- Ensured `OPENCLAW_CONFIG_DIR` is prepared before ownership safety checks, including custom config-dir paths.
- Added hermetic ownership/config-dir validation coverage and aligned contributor validation docs with current `make check` / `make check-strict` targets.
- Added post-install helper scripts (`update.sh`, `add_tool.sh`) with git-checkout-aware update behavior and hermetic test coverage.
- Added compatibility matrix documentation for OVH Ubuntu + Docker/Compose/Traefik/OpenClaw deployment baselines.

## Prioritized backlog (next 5 items)

1. Add module-level tests for image stamp and validation helper paths.
2. Add failure-injection tests for DNS mismatch and delayed ACME issuance.
3. Add CI scenario that exercises both root and non-root ownership/permission checks.
4. Add release checklist and version-tagging workflow.
5. Add Ubuntu package drift guard checks to security audit automation.
