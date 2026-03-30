# Operations

## Deploy/update paths

- First deploy: `setup.sh`
- Ongoing deploy: `sync.sh`
- In-place maintenance deploy: `update.sh`

## Backup

```sh
sh ./backup.sh
```

## Restore

```sh
RESTORE_ARCHIVE=./openclaw-backup-YYYYmmdd-HHMMSS.tar.gz \
RESTORE_ROOT=/ \
RESTORE_FORCE=1 \
sh ./restore.sh
```

`restore.sh` refuses `/` restores unless `RESTORE_FORCE=1`.
`restore.sh` also enforces:
- path-prefix allowlist (`RESTORE_ALLOWED_PREFIXES`, defaults to OpenClaw/Traefik paths under `$HOME`),
- symlink/hardlink rejection unless `RESTORE_ALLOW_LINKS=1`,
- optional preflight-only mode with `RESTORE_DRY_RUN=1`.

## Image runtime policy

agime pulls the official OpenClaw image (`ghcr.io/openclaw/openclaw:latest`) during deploy.
agime also rewrites `OPENCLAW_IMAGE=` in `~/openclaw/.env` to the official image during deploy/update to migrate older hosts off stale `openclaw:local` values.

## Incident diagnostics checklist

Run these on the OVH Ubuntu VPS when deploy health checks fail:

1. Compose/container status:
   - `docker compose -f ~/openclaw/docker-compose.yml ps`
   - `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'`
2. OpenClaw logs and health:
   - `docker logs --tail 200 openclaw`
   - `curl -fsS http://127.0.0.1:18789/healthz`
3. Traefik/public mode checks:
   - `docker logs --tail 200 traefik`
   - `curl -I https://$OPENCLAW_DOMAIN`
   - `curl -fsS https://$OPENCLAW_DOMAIN/healthz`
4. DNS/TLS/routing triage:
   - `getent ahostsv4 "$OPENCLAW_DOMAIN"`
   - verify the response `Server` header is Traefik and health endpoint returns HTTP 200.
