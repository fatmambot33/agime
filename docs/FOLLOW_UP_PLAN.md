# Follow-up Evolution Plan

Date: 2026-03-22
Last Updated: 2026-03-29

## Goal
Transform the repo into a maintainable, testable, and secure deployment toolkit that defaults to private access.

## Completed this cycle

- Introduced explicit access-mode model via `OPENCLAW_ACCESS_MODE` with default `ssh-tunnel` and opt-in `public` mode.
- Split OpenClaw compose templates into public and ssh-tunnel variants.
- Added change-aware `openclaw:local` rebuild logic with revision stamp tracking.
- Hardened post-build validation for both modes (local health in ssh-tunnel, HTTPS/TLS retry logic in public).
- Updated interactive setup and docs to be mode-aware and private-by-default.
- Added optional Signal channel bootstrap (`OPENCLAW_ENABLE_SIGNAL`) with template-backed `channels.signal` rendering.
- Added backup/restore helper scripts with explicit safety guard for root-level restore operations.
- Integrated optional pre-deploy backups into the interactive setup flow so operators can checkpoint before changes.
- Fixed ownership correction flow so setup works for both root and non-root execution contexts (optional sudo usage).
- Ensured `OPENCLAW_CONFIG_DIR` is prepared before ownership safety checks, including custom config-dir paths.
- Added hermetic ownership/config-dir validation coverage and aligned contributor validation docs with current `make check` / `make check-strict` targets.
- Added post-install helper scripts (`update.sh`, `add_tool.sh`) with git-checkout-aware update behavior and hermetic test coverage.
- Added compatibility matrix documentation for OVH Ubuntu + Docker/Compose/Traefik/OpenClaw deployment baselines.
- Clarified deployment boundaries: remote `sync.conf` as authoritative config, `configure.sh` as local config-authoring wizard, and runtime-only default sync payload for VPS execution.
- Shifted optional-tool handling to image-first runtime validation (GitHub, Himalaya, coding-agent, Signal) and removed runtime installers from the supported path.
- Updated docs/runbook guidance to standardize on prebuilt custom `OPENCLAW_IMAGE` + `SKIP_OPENCLAW_IMAGE_BUILD=1` for agent-enabled VPS deployments.
- Added a first-party custom image workflow (`docs/CUSTOM_IMAGE_WORKFLOW.md`) plus `scripts/build_custom_image.sh` and `templates/openclaw-custom-image.Dockerfile.tmpl` to streamline image creation.
- Simplified `setup.sh` into a clean install-only bootstrap that captures minimal env inputs and executes template-based `build.sh`.
- Kept `add_tool` available as an optional helper while tightening defaults around image-baked tool onboarding for setup 2.0.

## Prioritized backlog (next 5 items)

1. Add hermetic tests for image-first optional tool validation failures (missing in-container binaries by feature).
2. Add module-level tests for image stamp and validation helper paths.
3. Add failure-injection tests for DNS mismatch and delayed ACME issuance.
4. Add CI scenario that exercises both root and non-root ownership/permission checks.
5. Add release checklist and version-tagging workflow for prebuilt custom image tags.
