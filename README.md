# agime

Automation scripts for deploying an OpenClaw gateway behind Traefik on a VPS.

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `build-interactive.sh`: guided wrapper that collects inputs and runs `build.sh`.
- `sync.sh`: minimal helper to copy and run setup scripts over SSH.
- `Makefile`: local quality checks (`make check`, `make lint`, `make fmt-check`).

## Prerequisites

- Linux VPS with SSH access and `sudo` rights.
- Docker with Docker Compose support (`docker compose`).
- Git.
- DNS A/AAAA record configured for `OPENCLAW_DOMAIN` and pointing to the VPS.
- Inbound network access to TCP ports `80` and `443`.

## Quick start

```bash
chmod +x build.sh
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Or use the interactive setup:

```bash
chmod +x build-interactive.sh
./build-interactive.sh
```

## Shell script execution setup

If you get `Permission denied` when running a script, mark it executable once:

```bash
chmod +x build.sh build-interactive.sh sync.sh
```

Then run scripts with either:

```bash
./build.sh
# or
sh ./build.sh
```

## `OPENCLAW_USER`: what it does and what to set

`OPENCLAW_USER` controls ownership for OpenClaw paths during setup:

- `$OPENCLAW_DIR`
- `$OPENCLAW_CONFIG_DIR`

Internally, `build.sh` runs:

```sh
sudo chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_DIR" "$OPENCLAW_CONFIG_DIR"
```

Recommended value:

- Set `OPENCLAW_USER` to the Linux account that should own and manage the OpenClaw files (usually your SSH login user).
- If you're unsure, use the default behavior (current user from `id -un`).

Examples:

```bash
# default/current user (recommended for most setups)
OPENCLAW_USER="$(id -un)"

# explicit service/admin user
OPENCLAW_USER=ubuntu
```

## Known limitations

- `build.sh` is still monolithic and not yet split into smaller sourced modules.
- The OpenClaw upstream wizard can still require interactive input unless `SKIP_OPENCLAW_WIZARD=1` and `.env` is pre-seeded.
- The scripts assume Docker is already installed and operational.

## Dry-run planning mode

Preview planned actions without changing host state:

```bash
DRY_RUN=1 \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

In dry-run mode, `build.sh` logs planned commands and file writes, skips Docker and filesystem changes, and uses a placeholder token when needed for config rendering.

## Post-deploy checks

After deployment, run:

```bash
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'traefik|openclaw'
docker logs --tail 50 traefik
docker logs --tail 50 openclaw
```

Then validate:

- `https://$OPENCLAW_DOMAIN` is reachable.
- Traefik obtained a certificate.
- OpenClaw gateway responds and device approvals are visible.

## Uninstall notes

To remove deployed services and generated assets:

```bash
( cd "$HOME/openclaw" && docker compose down ) || true
( cd "$HOME/docker/traefik" && docker compose down ) || true
docker network rm proxy || true
rm -rf "$HOME/openclaw" "$HOME/.openclaw" "$HOME/docker/traefik"
```

Back up data before deletion. See `docs/OPERATIONS.md` for backup/restore guidance.

## Reinstall procedure

Use this when you want to fully reset and deploy cleanly again on the same host.

1. Backup current state (optional but recommended):

```bash
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/backups/openclaw-$TS"
cp -a "$HOME/.openclaw" "$HOME/backups/openclaw-$TS/.openclaw" || true
cp -a "$HOME/openclaw/.env" "$HOME/backups/openclaw-$TS/openclaw.env" || true
cp -a "$HOME/docker/traefik" "$HOME/backups/openclaw-$TS/traefik" || true
```

2. Remove existing deployment artifacts:

```bash
( cd "$HOME/openclaw" && docker compose down ) || true
( cd "$HOME/docker/traefik" && docker compose down ) || true
docker network rm proxy || true
rm -rf "$HOME/openclaw" "$HOME/.openclaw" "$HOME/docker/traefik"
```

3. Reinstall with a fresh run of `build.sh`:

```bash
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

4. Validate using the post-deploy checks in this README.

## Developer checks

Run all quality gates:

```bash
make check
```

If needed, run each check independently:

```bash
make lint
make fmt-check
make syntax
```

## Documentation

- [Agent operating guide](AGENTS.md)
- [Repository review](docs/REPO_REVIEW.md)
- [Follow-up evolution plan](docs/FOLLOW_UP_PLAN.md)
- [Operations runbook](docs/OPERATIONS.md)
- [Contributing conventions](docs/CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
