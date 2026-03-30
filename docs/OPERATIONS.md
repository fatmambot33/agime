# Operations Runbook

## Mode-first troubleshooting

Deployment model note: Docker is the required runtime boundary for supported VPS deployments.

### 0) `sync.sh` asks for SSH password multiple times
- `sync.sh` runs from your local machine and performs three remote operations (`ssh mkdir`, `scp`, then remote entrypoint execution; default is `build.sh`).
- It enables SSH multiplexing by default (`ControlMaster=auto` + `ControlPersist`) so one authenticated control session is reused.
- If repeated prompts continue, verify your SSH client supports multiplexing and optionally set:
  - `SSH_CONTROL_PERSIST_SECONDS=1200`
  - `SSH_CONTROL_PATH="$HOME/.ssh/agime-sync-%r@%h:%p"`
- Prefer keeping sync + build options in `sync.conf` (copy from `sync.conf.example`) and enable `SYNC_PRINT_CONFIG=1` so current effective values are shown before each run.
- If `sync.conf` is missing, `sync.sh` first tries to download remote `sync.conf`; if not found remotely, it bootstraps local config from `sync.conf.example`.
- Shared `sync.conf` is normalized to home-relative paths (for example `~/openclaw`, `~/.openclaw`) for `OPENCLAW_*` + `TRAEFIK_DIR`, which keeps one machine-agnostic config usable on both workstation and VPS.
- Treat `sync.conf` as the local source-of-truth for authoring/updating deploy settings; `build.sh` remains the default remote entrypoint.
- `SYNC_REMOTE_CONFIG_PRIORITY=1` by default: if remote `SYNC_REMOTE_ENV_FILE` already exists, `sync.sh` treats it as authoritative for the run and refreshes local `sync.conf` from it.
- For non-interactive deploys, use `SYNC_REMOTE_ENTRYPOINT=build.sh` and keep required build variables in `sync.conf` (single source of truth).
- `sync.sh` prints a preflight warning when `SYNC_REMOTE_ENTRYPOINT=build.sh` and `OVH_ENDPOINT_API_KEY` is empty in loaded config/environment.
- By default, `sync.sh` sources `SYNC_REMOTE_ENV_FILE=sync.conf` remotely under `set -a` (plain `KEY=value` lines auto-export). It uploads local `sync.conf` only when remote priority is disabled or when the remote env file does not already exist.
- If those two paths are the same file (default), `sync.sh` now uploads it once (no duplicate `scp` line for `sync.conf`).
- Set `SYNC_MIRROR_ENV_FILE=1` when you want generated env values copied back locally after the run.

### 1) ssh-tunnel mode is unreachable locally
- Symptom: browser cannot load `http://127.0.0.1:18789` after tunnel setup.
- Fix:
  1. Re-check tunnel command: `ssh -N -L 18789:127.0.0.1:18789 <user>@<host>`.
  2. On host, confirm OpenClaw listens on loopback:
     `ss -lntp | grep 18789`.
  3. Check OpenClaw logs: `docker logs openclaw`.
  4. Verify health endpoint on host: `curl -f http://127.0.0.1:18789/healthz`.

### 2) public mode TLS certificate does not issue yet
- Symptom: HTTPS endpoint stays unavailable early after deploy.
- Fix:
  1. Confirm DNS (`OPENCLAW_DOMAIN`) points to host.
  2. Confirm inbound TCP `80`/`443` reachability.
  3. Check Traefik logs: `docker logs traefik`.
  4. Increase validation budget when issuance is slow:
     - `POST_BUILD_TEST_ATTEMPTS=60`
     - `POST_BUILD_TEST_DELAY_SECONDS=5`

## Connectivity validation behavior

- `ssh-tunnel`: validates `http://127.0.0.1:18789/healthz`.
- `public`: validates `https://$OPENCLAW_DOMAIN`.
- Public validation retries temporary cert states while ACME settles.
- Public validation accepts successful TLS/connectivity even if root returns HTTP `404`.

## Backup/restore/reinstall by mode

- `ssh-tunnel` mode backup targets:
  - `$HOME/.openclaw`
  - `$HOME/.openclaw/workspace` (or your custom `OPENCLAW_WORKSPACE_DIR`)
  - `$HOME/.openclaw/skills` and `$HOME/.openclaw/hooks` when present
  - `$HOME/.openclaw/paired-devices.json` when present
  - `$HOME/openclaw/.env`
- `public` mode backup targets include the above plus:
  - `$HOME/docker/traefik`
- `build.sh` stores timestamped `openclaw.json` backups under `$HOME/openclaw-backups` by default (override with `OPENCLAW_JSON_BACKUP_DIR`).

Use repo-provided helpers:

Post-install maintenance helpers:

```sh
# backup
sh ./backup.sh

# update toolkit + rerun deploy (git pull is auto-detected)
sh ./update.sh

# update.sh default flow: backup -> load ./.sync-build.env ->
# optional docker pull for OPENCLAW_IMAGE (image-first mode) -> build/deploy.
# backup step is validated: update fails early if backup archive is missing.

# force update pull only when this directory is a git checkout
GIT_PULL=1 sh ./update.sh

# skip loading deployment defaults file for one run
LOAD_DEPLOY_ENV=0 sh ./update.sh

# skip automatic backup or image pull for a one-off run
RUN_BACKUP=0 RUN_IMAGE_PULL=0 sh ./update.sh

# attempt automatic rollback from update backup when build fails
RESTORE_ON_FAILURE=1 sh ./update.sh
```

```sh
# backup (default targets)
sh ./backup.sh

# include Traefik state for public mode
INCLUDE_TRAEFIK=1 sh ./backup.sh

# include full OpenClaw checkout and extra custom files
INCLUDE_OPENCLAW_REPO=1 \
EXTRA_BACKUP_PATHS="$HOME/notes/IDENTITY.md" \
sh ./backup.sh
```

For an OVH-focused bootstrap, run `REMOTE_HOST=<user>@<host> sh ./setup.sh`; it collects required deploy inputs locally and deploys remotely via `sync.sh` over SSH.

Restore safely to a sandbox path first:

```sh
RESTORE_ARCHIVE="$HOME/openclaw-backup.tgz" \
RESTORE_ROOT="/tmp/openclaw-restore-check" \
sh ./restore.sh
```

Restore into `/` only when ready:

```sh
RESTORE_ARCHIVE="$HOME/openclaw-backup.tgz" \
RESTORE_FORCE=1 \
sh ./restore.sh
```

Reinstall clean reset:

```sh
( cd "$HOME/openclaw" && docker compose down ) || true
( cd "$HOME/docker/traefik" && docker compose down ) || true
docker network rm proxy || true
rm -rf "$HOME/openclaw" "$HOME/.openclaw" "$HOME/docker/traefik"
```

For `ssh-tunnel`-only deployments, Traefik directory/network cleanup is usually a no-op.


## OVH Ubuntu production posture checklist

Use this short checklist for final readiness reviews:

1. **Host baseline**
   - Confirm Ubuntu LTS and Docker/Compose versions match the compatibility guidance in `docs/COMPATIBILITY_MATRIX.md`.
2. **Network boundary**
   - Prefer `OPENCLAW_ACCESS_MODE=ssh-tunnel` unless public HTTPS access is explicitly required.
   - In `public` mode, restrict inbound rules to only `22`, `80`, and `443`.
3. **Secrets hygiene**
   - Keep `sync.conf` local-only (gitignored), especially when it contains API keys/tokens.
   - Ensure mirrored env files remain `chmod 600`.
4. **Recoverability**
   - Take a pre-change backup (`backup.sh`) and confirm archive existence before upgrades.
5. **Post-change verification**
   - Run mode-specific health checks and inspect `docker logs openclaw` (plus `docker logs traefik` in public mode).
