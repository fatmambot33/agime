# agime

Automation scripts for deploying OpenClaw on a VPS with two explicit access modes:

- `ssh-tunnel` (default, private access)
- `public` (Traefik + Let's Encrypt, explicit opt-in)

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `build-interactive.sh`: guided wrapper that collects inputs and runs `build.sh`.
- `sync.sh`: helper to copy setup scripts (`build-interactive.sh`, `build.sh`, `backup.sh`, `restore.sh`) plus required `scripts/` and `templates/` dependencies over SSH, then run setup remotely.
- `backup.sh`: creates a tarball backup of OpenClaw runtime data (`$OPENCLAW_CONFIG_DIR`, `$OPENCLAW_DIR/.env`, optional Traefik state).
- `restore.sh`: restores a backup tarball into a chosen root path (requires explicit force flag for `/`).
- `scripts/build_lib.sh` + `scripts/build_steps.sh`: shared helpers and modular deployment steps used by `build.sh`.
- `templates/openclaw-compose.ssh-tunnel.yml.tmpl`: private/local compose template.
- `templates/openclaw-compose.public.yml.tmpl`: Traefik-integrated compose template.
- `templates/traefik-compose.yml.tmpl`: Traefik compose template (public mode only).
- `templates/openclaw.json.tmpl`: OpenClaw JSON config template.
- `Makefile`: local quality checks.

## Quick start

### Safer default (`ssh-tunnel`)

```bash
chmod +x build.sh
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Then tunnel from your workstation:

```bash
ssh -N -L 18789:127.0.0.1:18789 <user>@<host>
```

Open: `http://127.0.0.1:18789`

### Public mode (explicit opt-in)

```bash
OPENCLAW_ACCESS_MODE=public \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

## Start using OpenClaw after deploy

### `ssh-tunnel` mode

1. Keep an SSH tunnel open from your workstation to the VPS:

   ```bash
   ssh -N -L 18789:127.0.0.1:18789 <user>@<host>
   ```

2. Open OpenClaw in your local browser:

   ```text
   http://127.0.0.1:18789
   ```

### `public` mode

1. Open OpenClaw in your browser:

   ```text
   https://<OPENCLAW_DOMAIN>
   ```

2. If the site is not immediately reachable, check DNS and certificate progress:
   - `docker logs traefik`
   - `docker logs openclaw`

## Pairing and approving devices

After OpenClaw is up, pair from the client app/flow you intend to use.

- New devices remain subject to gateway approvals in token mode.
- List pending/known devices on the VPS:

  ```bash
  docker exec -it openclaw node dist/index.js devices list
  ```

- Use the corresponding `devices` subcommands in that CLI to approve/reject as needed.

Operational note: pairing by itself is not a network exposure boundary; prefer `ssh-tunnel` unless public access is explicitly required.

## Access mode behavior

### `ssh-tunnel` (default)

- Skips Traefik setup/startup.
- Skips `proxy` network setup.
- Binds OpenClaw on `127.0.0.1:18789`.
- Post-build validation probes `http://127.0.0.1:18789/healthz`.

### `public`

- Uses Traefik + Let's Encrypt.
- Uses Docker `proxy` network.
- Post-build validation probes `https://$OPENCLAW_DOMAIN`.
- Validation accepts successful TLS/connectivity even if root returns `404`.

## Change-aware local image rebuilds

The deployment builds `openclaw:local` only when needed:

- image missing,
- revision stamp missing, or
- OpenClaw git revision changed.

Last built revision is saved in `$OPENCLAW_CONFIG_DIR/openclaw-image-revision.txt`.

Escape hatch:

```bash
SKIP_OPENCLAW_IMAGE_BUILD=1 ./build.sh
```

## Post-build connectivity validation

Enabled by default (`POST_BUILD_TEST=1`). Tunables:

- `POST_BUILD_TEST_ATTEMPTS` (default `40`)
- `POST_BUILD_TEST_DELAY_SECONDS` (default `3`)
- `POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS` (default `5`)
- `POST_BUILD_TEST_MAX_TIME_SECONDS` (default `15`)

Public-mode retry logic treats temporary default/self-signed cert states as transient while ACME issuance finishes.

## Signal channel setup (optional)

This toolkit can bootstrap Signal prerequisites and preconfigure `channels.signal` in `openclaw.json`.

```bash
OPENCLAW_ENABLE_SIGNAL=1 \
OPENCLAW_SIGNAL_ACCOUNT=+15551234567 \
OPENCLAW_SIGNAL_ALLOW_FROM=+15557654321 \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Behavior:

- When `OPENCLAW_ENABLE_SIGNAL=1`, the script validates `signal-cli` and can auto-install it from upstream GitHub releases (`OPENCLAW_SIGNAL_AUTO_INSTALL=1`, default).
- Rendered config includes `channels.signal.enabled=true`, the configured account, `cliPath`, and optional single-entry DM allowlist.
- After deployment, complete Signal registration/linking and approve pairing codes from the host:
  - `openclaw pairing list signal`
  - `openclaw pairing approve signal <CODE>`

## Security checklist (validated defaults)

- [x] Default access path is private (`OPENCLAW_ACCESS_MODE=ssh-tunnel`).
- [x] Gateway auth mode is `token` in `templates/openclaw.json.tmpl`.
- [x] `allowedOrigins` is explicit and templated (no wildcard).
- [x] Gateway default port is `18789`.
- [x] Traefik exposure is opt-in (`OPENCLAW_ACCESS_MODE=public`).
- [x] Secret-bearing rendered files are `chmod 600`.
- [x] OpenClaw config directory is `chmod 700`.

## Developer checks

```bash
make check
```

Or run the minimum syntax check directly:

```bash
sh -n build.sh build-interactive.sh sync.sh backup.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/build_interactive_backup_hermetic.sh
```

## Backup and restore mechanic

`build-interactive.sh` includes an explicit pre-deploy backup prompt (enabled by default unless `DRY_RUN=1`) so you can capture a restore point before changes are applied.

Backup defaults:
- Includes `$OPENCLAW_CONFIG_DIR` (default `$HOME/.openclaw`).
- Includes `$OPENCLAW_DIR/.env` (default `$HOME/openclaw/.env`).
- Includes `$OPENCLAW_DIR/docker-compose.yml` when present.
- Excludes Traefik data by default unless `INCLUDE_TRAEFIK=1`.
- Excludes full OpenClaw git checkout by default unless `INCLUDE_OPENCLAW_REPO=1`.
- Supports additional paths via `EXTRA_BACKUP_PATHS` (space-separated).

Create a backup:

```bash
sh ./backup.sh
```

Tune backup location and include Traefik:

```bash
INCLUDE_TRAEFIK=1 \
BACKUP_OUTPUT="$HOME/openclaw-backup.tgz" \
sh ./backup.sh
```

Include the full local OpenClaw checkout plus extra files:

```bash
INCLUDE_OPENCLAW_REPO=1 \
EXTRA_BACKUP_PATHS="$HOME/notes/IDENTITY.md $HOME/.config/openclaw/custom.env" \
sh ./backup.sh
```

Restore to a safe sandbox path first (recommended):

```bash
RESTORE_ARCHIVE="$HOME/openclaw-backup.tgz" \
RESTORE_ROOT="/tmp/openclaw-restore-check" \
sh ./restore.sh
```

Restore into the real filesystem root (requires explicit opt-in):

```bash
RESTORE_ARCHIVE="$HOME/openclaw-backup.tgz" \
RESTORE_FORCE=1 \
sh ./restore.sh
```

## Signal docs

- <https://docs.openclaw.ai/channels/signal>

## GitHub skill prerequisites

If you plan to use the OpenClaw GitHub skill, enable prerequisite handling in the build:

```bash
OPENCLAW_ENABLE_GITHUB_SKILL=1 \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Behavior when enabled:

- Validates `gh` availability (`OPENCLAW_GH_CLI_PATH`, default `gh`).
- Auto-installs `gh` when missing (automatic; apt-get only).
- Enforces authentication by running `gh auth status` (`OPENCLAW_GH_REQUIRE_AUTH=1`, default).

If you prefer to install/auth manually, use the following:

1. Install `gh`:
   - Ubuntu/Debian: `sudo apt update && sudo apt install -y gh`
2. Authenticate once: `gh auth login`
3. Verify runtime visibility and auth state:
   - `which gh`
   - `gh auth status`

If auth validation fails, run `gh auth login` and rerun `build.sh`.

## Himalaya skill prerequisites

If you plan to use the OpenClaw Himalaya skill, enable prerequisite handling in the build:

```bash
OPENCLAW_ENABLE_HIMALAYA_SKILL=1 \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Behavior when enabled:

- Validates `himalaya` availability (`OPENCLAW_HIMALAYA_CLI_PATH`, default `himalaya`).
- Auto-installs `himalaya` when missing (automatic; apt-get only).
- If `OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64` is set, the script writes that content to `OPENCLAW_HIMALAYA_CONFIG_PATH` with `chmod 600`.
- Validates config presence by default (`OPENCLAW_HIMALAYA_REQUIRE_CONFIG=1`) at `OPENCLAW_HIMALAYA_CONFIG_PATH` (default `~/.config/himalaya/config.toml`).

If you prefer to install/configure manually, use the following:

1. Install `himalaya`:
   - Ubuntu/Debian: `sudo apt update && sudo apt install -y himalaya`
2. Create account config:
   - `himalaya account configure`
3. Verify access:
   - `which himalaya`
   - `himalaya --version`
   - `himalaya folder list`

If config validation fails, run `himalaya account configure` (or set `OPENCLAW_HIMALAYA_CONFIG_PATH` to your existing config) and rerun `build.sh`.

### Providing Himalaya credentials non-interactively

You can provide a fully formed `config.toml` via base64:

```bash
OPENCLAW_ENABLE_HIMALAYA_SKILL=1 \
OPENCLAW_HIMALAYA_CONFIG_PATH="$HOME/.config/himalaya/config.toml" \
OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64="$(base64 -w 0 /path/to/config.toml)" \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

This lets you inject credentials/config from your secret manager at runtime instead of running `himalaya account configure` interactively.
