# agime

Minimal deployment toolkit for OpenClaw on VPS hosts.

## Design principles

- Private-by-default: `OPENCLAW_ACCESS_MODE=ssh-tunnel` unless you explicitly opt into `public`.
- Non-interactive, environment-variable-driven execution first.
- Small number of entrypoints and modular shell internals.
- Auditable templates under `templates/` and deterministic tests under `tests/`.

## Repository layout

- `build.sh` — deploy OpenClaw on the remote host.
- `sync.sh` — sync this toolkit to a VPS and execute a selected remote entrypoint.
- `setup.sh` — non-interactive wrapper around `sync.sh` for first deploy.
- `backup.sh` — create an archive of OpenClaw runtime state.
- `restore.sh` — restore a backup archive (with root safety guard).
- `update.sh` — optional git pull + backup + build workflow on remote host.
- `scripts/` — shared shell modules used by entrypoints.
- `templates/` — render-only config templates.
- `tests/` — hermetic smoke/idempotency/failure-path checks.
- `docs/` — operator and contributor docs.

## Quick start

### 1) First deploy (non-interactive)

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
sh ./setup.sh
```

For public mode:

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=public \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
sh ./setup.sh
```

### 2) Ongoing remote apply

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
sh ./sync.sh
```

`sync.sh` uploads the runtime bundle and runs `build.sh` on the remote host by default.

## Access modes

- `ssh-tunnel` (default): binds OpenClaw to localhost only.
- `public`: enables Traefik + Let's Encrypt for internet-facing HTTPS access.

## Operations

- Backup:
  ```sh
  sh ./backup.sh
  ```
- Restore:
  ```sh
  RESTORE_ARCHIVE=./openclaw-backup-YYYYmmdd-HHMMSS.tar.gz RESTORE_ROOT=/ RESTORE_FORCE=1 sh ./restore.sh
  ```
- Update:
  ```sh
  sh ./update.sh
  ```

## Validation

Run the full local validation suite:

```sh
make check
```

For strict local checks (lint + formatting + tests):

```sh
make check-strict
```
