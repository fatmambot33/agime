# agime

Automation scripts for deploying an OpenClaw gateway behind Traefik on a VPS.

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `build-interactive.sh`: guided wrapper that collects inputs and runs `build.sh`.
- `sync.sh`: helper to copy setup scripts plus required `scripts/` and `templates/` dependencies over SSH, then run setup remotely.
- `scripts/build_lib.sh` + `scripts/build_steps.sh`: shared helpers and modular deployment steps used by `build.sh`.
- `Makefile`: local quality checks (`make check`, `make lint`, `make fmt-check`, `make smoke`, `make idempotency`, `make security`, `make sync-test`, `make security-audit-scripts`) plus runtime audit helpers (`make security-audit`, `make install-security-cron`).

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

Or sync scripts to a remote host and run interactive setup there:

```bash
REMOTE_HOST=my-vps REMOTE_DIR=/tmp/agime ./sync.sh
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

Before ownership updates are applied, the script validates each target path and refuses unsafe values (empty, `.`, `..`, `/`, or missing paths).

Recommended value:

- Set `OPENCLAW_USER` to the Linux account that should own and manage the OpenClaw files (usually your SSH login user).
- If you're unsure, use the default behavior (current user from `id -un`).
- You do **not** need to create a new account for most installs.

Examples:

```bash
# default/current user (recommended for most setups)
OPENCLAW_USER="$(id -un)"

# explicit service/admin user
OPENCLAW_USER=ubuntu
```

Optional hardening (advanced): you can create a dedicated system user and pass that user as `OPENCLAW_USER`, but this is not required for a normal setup.

## Template files (JSON + Compose)

The generated config files are now stored as templates:

- `templates/traefik-compose.yml.tmpl`
- `templates/openclaw-compose.yml.tmpl`
- `templates/openclaw.json.tmpl`

`build.sh` renders these templates into:

- `$TRAEFIK_DIR/docker-compose.yml`
- `$OPENCLAW_DIR/docker-compose.yml`
- `$OPENCLAW_CONFIG_DIR/openclaw.json`

The OpenClaw Compose template intentionally keeps Docker Compose variable interpolation syntax (for example `${OPENCLAW_CONFIG_DIR}`) unescaped so rendered YAML remains valid for `docker compose`.

If needed, you can override template paths with:

```bash
TRAEFIK_COMPOSE_TEMPLATE=/path/to/traefik-compose.yml.tmpl
OPENCLAW_COMPOSE_TEMPLATE=/path/to/openclaw-compose.yml.tmpl
OPENCLAW_JSON_TEMPLATE=/path/to/openclaw.json.tmpl
```

## Known limitations

- Core setup logic is modularized, but still shell-based and not yet covered by unit-style module tests.
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

## Post-build HTTPS/TLS validation

`build.sh` performs an automated HTTPS/TLS validation against `https://$OPENCLAW_DOMAIN` after services are restarted. This catches common SSL issues immediately after deployment.

Behavior:

- Enabled by default (`POST_BUILD_TEST=1`).
- Uses `curl` retry checks before failing the run.
- Tunable retries (`POST_BUILD_TEST_ATTEMPTS`, default `20`).
- Tunable delay between attempts (`POST_BUILD_TEST_DELAY_SECONDS`, default `3`).
- Per-probe connect timeout (`POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS`, default `5`).
- Per-probe total timeout (`POST_BUILD_TEST_MAX_TIME_SECONDS`, default `15`).

To skip in constrained/staged environments:

```bash
POST_BUILD_TEST=0 \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

If `POST_BUILD_TEST=1`, `build.sh` validates `curl` availability before deployment steps start.

## Secret handling and file permissions

- `build-interactive.sh` redacts secret values in the confirmation summary.
- `build.sh` redacts gateway token output in the completion summary.
- Generated `$OPENCLAW_CONFIG_DIR/openclaw.json` and backup files are forced to mode `600`.
- `$OPENCLAW_CONFIG_DIR` is forced to mode `700` when config is rendered.

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

Run strict gates (includes lint + format checks):

```bash
make check-strict
```

`make check-strict` will attempt to install `shellcheck` and `shfmt` via `apt-get` if they are missing.

If needed, run each check independently:

```bash
make lint
make fmt-check
make syntax
make smoke
make idempotency
make security
make sync-test
make security-audit-scripts
make check-strict
```

Recommended runtime audit on a deployed gateway:

```bash
docker exec openclaw openclaw security audit
docker exec openclaw openclaw security audit --deep
docker exec openclaw openclaw security audit --json
docker exec openclaw openclaw security audit --fix
```

Automate this daily with cron:

```bash
make install-security-cron
```

This installs a daily cron entry that runs `scripts/run_security_audit.sh` at **12:00 GMT** by default (`CRON_TZ=Etc/GMT` + `0 12 * * *`), executes `audit`, `audit --deep`, and stores a JSON report. The script uses the deployed container runner (`docker exec openclaw ...`) by default; set `OPENCLAW_SECURITY_AUDIT_RUNNER=host` only if you have an `openclaw` CLI installed on the host. By default it does **not** run `--fix`; set `OPENCLAW_SECURITY_AUDIT_FIX=1` in crontab only if you explicitly want automated remediation.

## Documentation

- [Agent operating guide](AGENTS.md)
- [Repository review](docs/REPO_REVIEW.md)
- [Follow-up evolution plan](docs/FOLLOW_UP_PLAN.md)
- [Operations runbook](docs/OPERATIONS.md)
- [Contributing conventions](docs/CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
