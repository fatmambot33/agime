# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Added
- Added `OPENCLAW_ACCESS_MODE` with supported values `ssh-tunnel` (default) and `public`.
- Added split compose templates for each access mode:
  - `templates/openclaw-compose.ssh-tunnel.yml.tmpl`
  - `templates/openclaw-compose.public.yml.tmpl`
- Added change-aware local image rebuild logic with revision stamp tracking at `$OPENCLAW_CONFIG_DIR/openclaw-image-revision.txt`.
- Added optional Signal bootstrap controls:
  - `OPENCLAW_ENABLE_SIGNAL`
  - `OPENCLAW_SIGNAL_ACCOUNT`
  - `OPENCLAW_SIGNAL_ALLOW_FROM`
  - `OPENCLAW_SIGNAL_CLI_PATH`
  - `OPENCLAW_SIGNAL_AUTO_INSTALL`
- Added automatic `signal-cli` dependency check/installation flow (opt-out via `OPENCLAW_SIGNAL_AUTO_INSTALL=0`) when Signal is enabled.
- Added `backup.sh` and `restore.sh` mechanics for reproducible backup/restore of deployment data with explicit restore safety guard (`RESTORE_FORCE=1` for `/`).
- Added `tests/ownership_config_dir_hermetic.sh` to cover ownership handling for root/non-root execution and custom `OPENCLAW_CONFIG_DIR` preparation flows.
- Added post-install helpers:
  - `update.sh` to rerun maintenance deploys with optional git update behavior.
  - `add_tool.sh` to enable optional tools (`signal`, `github`, `himalaya`, `coding-agent`) and rerun deploy.
- Added `tests/post_install_helpers_hermetic.sh` to validate helper behavior without Docker/network dependencies.

### Changed
- Changed default deployment posture to private mode (`ssh-tunnel`) with loopback-only binding on `127.0.0.1:18789`.
- Kept Traefik/HTTPS flow available only in explicit `public` mode.
- Fixed public Traefik router label rendering for host rule syntax.
- Increased default post-build retry budget and made validation mode-aware.
- Treated temporary self-signed/default TLS cert state as retryable during ACME issuance.
- Accepted successful TLS/connectivity even when app root returns HTTP `404`.
- Updated interactive setup prompts and completion output to reflect selected mode.
- Updated README, operations runbook, and follow-up plan to reflect private-first guidance.
- Updated OpenClaw JSON template defaults to include a `channels.signal` section with explicit `enabled`, `account`, `cliPath`, and DM pairing-oriented defaults.
- Updated Signal auto-install validation to verify the configured `OPENCLAW_SIGNAL_CLI_PATH` (including custom command/path values) after installation.
- Updated README and operations runbook with backup/restore usage and safe restore workflow.
- Expanded backup coverage/options to include `docker-compose.yml` by default plus opt-in full repo capture (`INCLUDE_OPENCLAW_REPO=1`) and arbitrary extra paths (`EXTRA_BACKUP_PATHS`).
- Fixed `backup.sh` handling for relative `BACKUP_OUTPUT` so archives are written relative to caller working directory (not staging temp dir).
- Hardened `restore.sh` root safety check by normalizing `RESTORE_ROOT` path variants (for example `//`) before enforcing `RESTORE_FORCE=1`.
- Integrated pre-deploy backup flow into `configure.sh` with explicit operator prompts and backup option passthrough.
- Fixed backup staging path merge behavior so `INCLUDE_OPENCLAW_REPO=1` no longer nests restore paths as `<OPENCLAW_DIR>/openclaw/...`.
- Removed legacy compatibility exports from `configure.sh` so `build.sh` owns all default resolution directly.
- Fixed backup staging for relative source paths so archives include relative `OPENCLAW_DIR`, `OPENCLAW_CONFIG_DIR`, and `EXTRA_BACKUP_PATHS` entries correctly.
- Fixed ownership correction in `prepare_openclaw_repo` to support both root and non-root execution contexts by using `sudo` only when required.
- Fixed custom `OPENCLAW_CONFIG_DIR` brittleness by preparing the config path before ownership safety checks.
- Updated `README.md` and `docs/CONTRIBUTING.md` validation guidance to match current `make check` and `make check-strict` behavior.
- Updated optional skill prerequisite flow to install/validate runtime binaries (`gh`, `himalaya`, coding-agent backend) inside the running `openclaw` container.
- Updated default `OPENCLAW_HIMALAYA_CONFIG_PATH` to `$OPENCLAW_CONFIG_DIR/himalaya/config.toml` and mounted `${OPENCLAW_CONFIG_DIR}/himalaya` into the container for runtime config access.
- Refactored optional skill handling into per-tool scripts under `scripts/optional_tools/` for cleaner extension as new tools are added.
- Updated `update.sh` to be git-checkout aware (`GIT_PULL=auto` by default) so it works in both cloned and synced toolkit directories.
- Updated post-install helpers to auto-load `OVH_ENDPOINT_API_KEY` from `$OPENCLAW_DIR/.env` when not already exported.
- Removed backward-compatibility toggles `OPENCLAW_GH_REQUIRE_AUTH` and `OPENCLAW_CODING_AGENT_REQUIRE_VERSION_CHECK`; runtime prerequisite checks are now always enforced when corresponding optional skills are enabled.
- Updated `sync.sh` env-file handling to upload `SYNC_LOCAL_ENV_FILE` (fallback `SYNC_REMOTE_ENV_FILE`) to the configured remote env path before remote execution.
- Expanded backup coverage for workspace, skills, hooks, and paired-device state paths (with override env vars for non-default locations).
- Changed OpenClaw JSON backup behavior to write timestamped `.bak` files under `OPENCLAW_JSON_BACKUP_DIR` (default `$HOME/openclaw-backups`) instead of `.openclaw`.
- Renamed the interactive setup entrypoint from `build-interactive.sh` to `configure.sh` to make config-authoring responsibilities explicit.
- Removed `build-interactive.sh`; `configure.sh` is now the only supported interactive/configuration entrypoint.
- Updated sync defaults/docs so remote `sync.conf` is explicit source of truth, deployment execution remains remote (`build.sh`), and default `SYNC_ITEMS` is limited to runtime deployment files.
