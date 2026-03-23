# Operations Runbook

## Troubleshooting

### 1) `docker ps` fails in `build.sh`
- Symptom: script exits after Docker access check.
- Fix:
  1. Ensure Docker is installed and running.
  2. If needed, rerun with default group setup behavior (`SKIP_DOCKER_GROUP_SETUP=0`) and reconnect your session.
  3. Re-run deployment script.

### 2) TLS certificate does not issue
- Symptom: HTTPS endpoint stays unavailable.
- Fix:
  1. Confirm `OPENCLAW_DOMAIN` A/AAAA record points to the host.
  2. Confirm ports `80` and `443` are publicly reachable.
  3. Check Traefik logs: `docker logs traefik`.

### 3) OpenClaw container exits immediately
- Symptom: `openclaw` container keeps restarting.
- Fix:
  1. Check container logs: `docker logs openclaw`.
  2. Verify `.env` exists in `OPENCLAW_DIR`.
  3. Verify gateway token and OVH variables in `$HOME/.openclaw/openclaw.json`.

## Dry-run validation

Use dry-run mode to preview deployment actions safely before touching host state:

```sh
DRY_RUN=1 \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Dry-run output prefixes planned operations with `[DRY_RUN]` and does not apply Docker, sudo, or filesystem changes.

## Scheduled security audits (daily cron)

You can schedule OpenClaw security audits to run daily:

```sh
make install-security-cron
```

Installed cron behavior:

- Runs `scripts/run_security_audit.sh` once per day (`17 3 * * *` by default).
- Executes:
  - `openclaw security audit`
  - `openclaw security audit --deep`
  - `openclaw security audit --json` (saved under `~/.openclaw/security-audit/`)
- Skips `openclaw security audit --fix` by default.

To change schedule, reinstall with:

```sh
OPENCLAW_SECURITY_AUDIT_CRON_SCHEDULE="0 2 * * *" make install-security-cron
```

To enable automated `--fix` (use with caution), edit the installed cron line and set:

```sh
OPENCLAW_SECURITY_AUDIT_FIX=1
```

## Backup

Create a timestamped backup before upgrades or major configuration changes:

```sh
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/backups/openclaw-$TS"
cp -a "$HOME/.openclaw" "$HOME/backups/openclaw-$TS/.openclaw"
cp -a "$HOME/openclaw/.env" "$HOME/backups/openclaw-$TS/openclaw.env"
cp -a "$HOME/docker/traefik" "$HOME/backups/openclaw-$TS/traefik"
```

## Restore

```sh
cp -a "$HOME/backups/<stamp>/.openclaw" "$HOME/.openclaw"
cp -a "$HOME/backups/<stamp>/openclaw.env" "$HOME/openclaw/.env"
cp -a "$HOME/backups/<stamp>/traefik" "$HOME/docker/traefik"
```

Then restart services:

```sh
( cd "$HOME/docker/traefik" && docker compose up -d )
( cd "$HOME/openclaw" && docker compose up -d )
```

## Reinstall (clean reset)

Use this procedure when the host state is inconsistent and you prefer a full redeploy.

1. Optional backup:

```sh
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/backups/openclaw-$TS"
cp -a "$HOME/.openclaw" "$HOME/backups/openclaw-$TS/.openclaw" || true
cp -a "$HOME/openclaw/.env" "$HOME/backups/openclaw-$TS/openclaw.env" || true
cp -a "$HOME/docker/traefik" "$HOME/backups/openclaw-$TS/traefik" || true
```

2. Remove current services and assets:

```sh
( cd "$HOME/openclaw" && docker compose down ) || true
( cd "$HOME/docker/traefik" && docker compose down ) || true
docker network rm proxy || true
rm -rf "$HOME/openclaw" "$HOME/.openclaw" "$HOME/docker/traefik"
```

3. Re-run deployment script with required environment variables:

```sh
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

4. Verify Traefik and OpenClaw health (logs and HTTPS endpoint).

## Rollback

If a deployment update fails:

1. Stop changed services:
   ```sh
   ( cd "$HOME/openclaw" && docker compose down )
   ```
2. Restore from latest backup (see restore section).
3. Restart Traefik and OpenClaw.
4. Validate endpoint health from browser and logs.
