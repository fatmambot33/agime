# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Added
- Added `OPENCLAW_ACCESS_MODE` with supported values `ssh-tunnel` (default) and `public`.
- Added split compose templates for each access mode:
  - `templates/openclaw-compose.ssh-tunnel.yml.tmpl`
  - `templates/openclaw-compose.public.yml.tmpl`
- Added change-aware local image rebuild logic with revision stamp tracking at `$OPENCLAW_CONFIG_DIR/openclaw-image-revision.txt`.

### Changed
- Changed default deployment posture to private mode (`ssh-tunnel`) with loopback-only binding on `127.0.0.1:18789`.
- Kept Traefik/HTTPS flow available only in explicit `public` mode.
- Fixed public Traefik router label rendering for host rule syntax.
- Increased default post-build retry budget and made validation mode-aware.
- Treated temporary self-signed/default TLS cert state as retryable during ACME issuance.
- Accepted successful TLS/connectivity even when app root returns HTTP `404`.
- Updated interactive setup prompts and completion output to reflect selected mode.
- Updated README, operations runbook, and follow-up plan to reflect private-first guidance.
