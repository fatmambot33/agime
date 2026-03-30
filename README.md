# agime

Clean deployment toolkit for OpenClaw on VPS hosts.

## What this repo does

- Deploy OpenClaw with a private-by-default posture.
- Support exactly two access modes:
  - `ssh-tunnel` (default)
  - `public` (explicit opt-in via Traefik + Let's Encrypt)
- Provide first-class operations for backup, restore, and update.

## Entrypoints

- `build.sh` — deploy/apply on a VPS host.
- `sync.sh` — local sync + remote execution.
- `setup.sh` — first-deploy wrapper around `sync.sh`.
- `backup.sh` — create backup archive.
- `restore.sh` — restore backup archive (with root safety guard).
- `update.sh` — optional pull + backup + deploy workflow.

## Repository structure

- `scripts/` — modular shell logic.
- `templates/` — render-only configuration assets.
- `tests/` — deterministic hermetic checks.
- `docs/` — operator/contributor/release docs.

## Quick start

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
sh ./setup.sh
```

`REMOTE_DIR` should point to a path under the remote user home (default `~/agime`). The scripts normalize host-expanded values (for example `/Users/alice/agime`) back to `~/...` for remote-safe sync behavior.

Public mode:

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=public \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
sh ./setup.sh
```

## Validation

```sh
make check
make check-strict
```

## First-run OpenClaw bootstrap behavior

- `build.sh` now bootstraps `OPENCLAW_DIR/.env` non-interactively when missing.
- The bootstrap writes a conservative subset used by agime:
  - `OPENCLAW_CONFIG_DIR`
  - `OPENCLAW_WORKSPACE_DIR`
  - `OPENCLAW_GATEWAY_PORT=18789`
  - `OPENCLAW_BRIDGE_PORT=18790`
  - `OPENCLAW_GATEWAY_BIND`
  - `OPENCLAW_GATEWAY_TOKEN`
  - `OPENCLAW_IMAGE`
- If `OPENCLAW_TOKEN` is set, that value is reused; otherwise agime generates a token via `openssl` (or `python3` fallback).
- If token generation is unavailable, agime falls back to `./docker-setup.sh` unless `SKIP_OPENCLAW_WIZARD=1`.
- `SKIP_OPENCLAW_WIZARD=1` is safe after `.env` already exists (either from bootstrap or one manual wizard run).

## Release and compatibility

- `docs/RELEASE_PROCESS.md`
- `docs/COMPATIBILITY_POLICY.md`
