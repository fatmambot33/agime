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

## First-run OpenClaw setup behavior

- On first run, `build.sh` runs OpenClaw's `./docker-setup.sh` wizard when `OPENCLAW_DIR/.env` is missing.
- Set `SKIP_OPENCLAW_WIZARD=1` only after `.env` already exists and you want fully non-interactive reruns.

## Release and compatibility

- `docs/RELEASE_PROCESS.md`
- `docs/COMPATIBILITY_POLICY.md`
