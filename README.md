# agime

Minimal deployment toolkit for OpenClaw on VPS hosts.

## Design principles

- Private-by-default (`OPENCLAW_ACCESS_MODE=ssh-tunnel` unless explicitly `public`).
- Non-interactive, environment-variable-driven operations first.
- Small set of clear entrypoints with modular shell logic in `scripts/lib/`.
- Deterministic local and CI validation.

## Entrypoints

- `build.sh` — deploy OpenClaw on a VPS host.
- `sync.sh` — local-to-remote sync and remote execution.
- `setup.sh` — first deploy wrapper around `sync.sh`.
- `backup.sh` — archive runtime state.
- `restore.sh` — restore runtime state with root safety guard.
- `update.sh` — optional pull + backup + deploy workflow.

## Repository layout

- `scripts/` — shared shell modules.
- `templates/` — rendered config assets only.
- `tests/` — hermetic smoke/idempotency/failure-path checks.
- `docs/` — operator and contributor docs.

## Quick start

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
sh ./setup.sh
```

Public mode (explicit opt-in):

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
sh -n build.sh setup.sh sync.sh
make check
make check-strict
```
