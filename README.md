# agime

Clean deployment toolkit for OpenClaw on OVH VPS hosts running Ubuntu LTS.

## What this repo does

- Deploy OpenClaw with a private-by-default posture.
- Support exactly two access modes:
  - `ssh-tunnel` (default)
  - `public` (explicit opt-in via Traefik + Let's Encrypt)
- Provide first-class operations for backup, restore, and update.
- Runtime target is explicit: OVH VPS on Ubuntu LTS.

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

Before first deploy on a fresh OVH VPS:
- ensure outbound network access so Docker + Docker Compose can be installed automatically if missing,
- collect `OVH_ENDPOINT_API_KEY` and select `OPENCLAW_ACCESS_MODE`,
- for public mode, also set `OPENCLAW_DOMAIN` and `TRAEFIK_ACME_EMAIL`,
- OpenClaw uses the official image `ghcr.io/openclaw/openclaw:latest`.
- if Docker socket access is not yet available for the current user, agime now continues this run with `sudo docker` and still adds the user to the `docker` group for future logins.

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

## Sync payload defaults

- `sync.sh` sends a fixed minimal payload based on `SYNC_REMOTE_ENTRYPOINT`:
  - `build.sh`: build scripts + mode-specific templates
  - `update.sh`: update/backup/build scripts + mode-specific templates
  - `backup.sh`: `backup.sh` only
  - `restore.sh`: `restore.sh` only
- mode-specific template selection honors `OPENCLAW_ACCESS_MODE` from shell env or `SYNC_LOCAL_ENV_FILE`.
- `SYNC_ITEMS` is retired; use `SYNC_ITEMS_FILE` (newline-delimited manifest in repo-relative paths) only for audited overrides.

## Strict config parsing (`sync.sh`)

- `SYNC_CONFIG_FILE` and `SYNC_LOCAL_ENV_FILE` are parsed as **data** (`KEY=VALUE`), not executed as shell.
- Quoted values are accepted (for example `REMOTE_DIR="~/agime"`).
- Unknown keys, multiline values, and shell-dangerous characters are rejected early.
- Supported keys are constrained to deploy/update/backup/restore inputs only.

## First-run OpenClaw setup behavior

- On first run, `build.sh` runs OpenClaw's `./docker-setup.sh` wizard when `OPENCLAW_DIR/.env` is missing.
- If this run is using `sudo docker` (for example right after docker-group changes), agime also launches the wizard with `sudo` so image build/setup can complete in the same session.
- This wizard step is mandatory for installs; skipping it is not supported.
- During deploy/update, agime normalizes `OPENCLAW_IMAGE` inside `OPENCLAW_DIR/.env` to `ghcr.io/openclaw/openclaw:latest` so stale `openclaw:local` values cannot break restarts.

## Release and compatibility

- `docs/RELEASE_PROCESS.md`
- `docs/COMPATIBILITY_POLICY.md`
