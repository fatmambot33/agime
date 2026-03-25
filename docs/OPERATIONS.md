# Operations Runbook

## Mode-first troubleshooting

### 0) `sync.sh` asks for SSH password multiple times
- `sync.sh` runs from your local machine and performs three remote operations (`ssh mkdir`, `scp`, then remote `build-interactive.sh`).
- It enables SSH multiplexing by default (`ControlMaster=auto` + `ControlPersist`) so one authenticated control session is reused.
- If repeated prompts continue, verify your SSH client supports multiplexing and optionally set:
  - `SSH_CONTROL_PERSIST_SECONDS=1200`
  - `SSH_CONTROL_PATH="$HOME/.ssh/agime-sync-%r@%h:%p"`
- Prefer keeping sync options in `sync.conf` (copy from `sync.conf.example`) and enable `SYNC_PRINT_CONFIG=1` so current effective values are shown before each run.
- For non-interactive deploys, use `SYNC_REMOTE_ENTRYPOINT=build.sh` and provide a remote env file via `SYNC_REMOTE_ENV_FILE`.
- `sync.conf` and `.sync-build.env` are gitignored because they can contain secrets.
- To reflect welcome answers into reusable config, set `SYNC_REMOTE_ENV_FILE=.sync-build.env` and `SYNC_MIRROR_ENV_FILE=1` so the generated env file is copied back to local.
- `sync.sh` now uploads `sync.conf` (from `SYNC_CONFIG_FILE`) and `.sync-build.env` automatically when those files exist locally.
- `build-interactive.sh` auto-runs non-interactive mode when `.sync-build.env` exists on host; set `OPENCLAW_FORCE_INTERACTIVE=1` to override.

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

### 3) Signal channel is enabled but not receiving messages
- Symptom: deploy succeeds, but Signal DMs do not produce replies.
- Fix:
  1. Confirm `signal-cli` exists on host and is executable:
     `signal-cli --version`.
  2. Confirm `openclaw.json` has a valid E.164 Signal account under `channels.signal.account`.
  3. Complete Signal link/register flow, then restart gateway:
     `systemctl --user restart openclaw-gateway` (or restart your container/service).
  4. Check pairing queue and approve pending codes:
     `openclaw pairing list signal`
     `openclaw pairing approve signal <CODE>`

## Connectivity validation behavior

- `ssh-tunnel`: validates `http://127.0.0.1:18789/healthz`.
- `public`: validates `https://$OPENCLAW_DOMAIN`.
- Public validation retries temporary cert states while ACME settles.
- Public validation accepts successful TLS/connectivity even if root returns HTTP `404`.

## Security guidance

- Preferred transport is private (`ssh-tunnel`, or private overlay like Tailscale).
- Public mode must be an explicit decision (`OPENCLAW_ACCESS_MODE=public`).
- Gateway auth should remain fail-closed (`token` mode).
- Device pairing alone is not a network-exposure control.
- OpenClaw gateway default port is `18789`.
- Keep allowlists and mention-gating controls enabled for group/chat surfaces.

## Backup/restore/reinstall by mode

- `ssh-tunnel` mode backup targets:
  - `$HOME/.openclaw`
  - `$HOME/openclaw/.env`
- `public` mode backup targets include the above plus:
  - `$HOME/docker/traefik`

Use repo-provided helpers:

Post-install maintenance helpers:

```sh
# backup
sh ./backup.sh

# update toolkit + rerun deploy (git pull is auto-detected)
sh ./update.sh

# enable one optional tool post-install
TOOL=github sh ./add_tool.sh

# force update pull only when this directory is a git checkout
GIT_PULL=1 sh ./update.sh
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

Interactive deploy note: `sh ./build-interactive.sh` now starts with a welcome menu (`Install`, `Update`, `Add Tool`, `Restore`, `Security`). The `Install` path still offers a pre-deploy backup step before running `build.sh`.

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
   - Keep `sync.conf` and `.sync-build.env` local-only (gitignored).
   - Ensure mirrored env files remain `chmod 600`.
4. **Recoverability**
   - Take a pre-change backup (`backup.sh`) and confirm archive existence before upgrades.
5. **Post-change verification**
   - Run mode-specific health checks and inspect `docker logs openclaw` (plus `docker logs traefik` in public mode).

