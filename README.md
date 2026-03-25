# agime

Automation scripts for deploying OpenClaw on a VPS with two explicit access modes:

- `ssh-tunnel` (default, private access)
- `public` (Traefik + Let's Encrypt, explicit opt-in)

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `build-interactive.sh`: guided entrypoint with a welcome menu (`Install`, `Update`, `Add Tool`, `Restore`, `Security`); `Install` collects inputs then runs `build.sh`.
- `sync.sh`: local helper that uploads toolkit files to a VPS first (scripts/templates/docs/README), then runs `build-interactive.sh` remotely over SSH (optionally preselecting `OPENCLAW_ACTION`).
- `backup.sh`: creates a tarball backup of OpenClaw runtime data (`$OPENCLAW_CONFIG_DIR`, `$OPENCLAW_DIR/.env`, optional Traefik state).
- `update.sh`: post-install helper that can fast-forward pull this toolkit checkout (auto-detected) and rerun `build.sh`.
- `add_tool.sh`: post-install helper to enable one optional tool (`signal`, `github`, `himalaya`, `coding-agent`) and rerun `build.sh`.
- `restore.sh`: restores a backup tarball into a chosen root path (requires explicit force flag for `/`).
- `scripts/build_lib.sh` + `scripts/build_steps.sh`: shared helpers and modular deployment steps used by `build.sh`.
- `scripts/optional_tools/*.sh`: per-tool optional runtime handlers (GitHub, Himalaya, coding-agent) plus shared container install/validation helpers.
- `templates/openclaw-compose.ssh-tunnel.yml.tmpl`: private/local compose template.
- `templates/openclaw-compose.public.yml.tmpl`: Traefik-integrated compose template.
- `templates/traefik-compose.yml.tmpl`: Traefik compose template (public mode only).
- `templates/openclaw.json.tmpl`: OpenClaw JSON config template.
- `Makefile`: local quality checks.

## Quick start

### Sync + remote welcome flow

Run from your local machine:

```bash
REMOTE_HOST=<user>@<host> sh ./sync.sh
```

Behavior:

- sync/upload is executed locally;
- the welcome menu (`build-interactive.sh`) is executed on the SSH host.

`sync.sh` now enables SSH connection multiplexing by default (`ControlMaster=auto` + `ControlPersist`), which usually avoids repeated password prompts across the multiple SSH/SCP calls.

Tune if needed:

```bash
SSH_CONTROL_PERSIST_SECONDS=1200 \
SSH_CONTROL_PATH="$HOME/.ssh/agime-sync-%r@%h:%p" \
REMOTE_HOST=<user>@<host> \
sh ./sync.sh
```

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

Primary validation target is Linux (OVH VPS runtime profile).

```bash
make check
```

`make check` runs syntax + hermetic script checks that model the supported Linux deployment flow.

`make check-strict` adds `shellcheck` + `shfmt` validation on top of `make check`.

Or run the syntax checks directly:

```bash
sh -n build.sh build-interactive.sh sync.sh backup.sh update.sh add_tool.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/build_interactive_backup_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh
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

## Post-install helpers

Create a backup before maintenance changes:

```bash
sh ./backup.sh
```

Update this toolkit checkout and rerun deployment (works in both a git clone and synced `/tmp/agime` copy):

```bash
sh ./update.sh
```

Control pull behavior explicitly when needed:

```bash
GIT_PULL=1 sh ./update.sh      # require git checkout and pull
GIT_PULL=0 sh ./update.sh      # skip pull and only rerun build
```

Enable one optional tool after initial install (example: GitHub CLI runtime support):

```bash
TOOL=github sh ./add_tool.sh
```

Both helpers auto-load `OVH_ENDPOINT_API_KEY` from `$OPENCLAW_DIR/.env` when not already exported.

Use dry-run previews when needed:

```bash
DRY_RUN=1 sh ./update.sh
DRY_RUN=1 TOOL=signal sh ./add_tool.sh
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

- Auto-installs `gh` inside the running `openclaw` container when missing (apt-get based).
- Validates that `gh` is available inside the running `openclaw` container runtime after restart.
- By default (`OPENCLAW_GH_REQUIRE_AUTH=1`), validates `gh auth status` inside the running container runtime after restart.

If you prefer to install/auth manually in the container, use:

1. Install `gh` in the running container:
   - `docker exec -u 0 openclaw sh -lc 'apt-get update && apt-get install -y gh'`
2. Authenticate in the runtime context as needed for your workflow.
   - `docker exec openclaw sh -lc 'gh auth login'`
3. Verify runtime visibility:
   - `docker exec openclaw sh -lc 'command -v gh'`
4. If `OPENCLAW_GH_REQUIRE_AUTH=1` (default), verify auth:
   - `docker exec openclaw sh -lc 'gh auth status'`

## Himalaya skill prerequisites

If you plan to use the OpenClaw Himalaya skill, enable prerequisite handling in the build:

```bash
OPENCLAW_ENABLE_HIMALAYA_SKILL=1 \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Behavior when enabled:

- Auto-installs `himalaya` inside the running `openclaw` container when missing (apt-get based).
- If `OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64` is set, the script writes that content to `OPENCLAW_HIMALAYA_CONFIG_PATH` with `chmod 600`.
- Validates config presence by default (`OPENCLAW_HIMALAYA_REQUIRE_CONFIG=1`) at `OPENCLAW_HIMALAYA_CONFIG_PATH` (default `$OPENCLAW_CONFIG_DIR/himalaya/config.toml`).
- Mounts `${OPENCLAW_CONFIG_DIR}/himalaya` into the container as `/home/node/.config/himalaya`.
- Validates that `himalaya` is available inside the running `openclaw` container runtime after restart.

If you prefer to install/configure manually in the container, use:

1. Install `himalaya` in the running container:
   - `docker exec -u 0 openclaw sh -lc 'apt-get update && apt-get install -y himalaya'`
2. Populate config at mounted path `${OPENCLAW_CONFIG_DIR}/himalaya/config.toml` (or use `OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64`).
3. Verify runtime visibility:
   - `docker exec openclaw sh -lc 'command -v himalaya'`

If config validation fails, run `himalaya account configure` (or set `OPENCLAW_HIMALAYA_CONFIG_PATH` to your existing config) and rerun `build.sh`.

### Providing Himalaya credentials non-interactively

You can provide a fully formed `config.toml` via base64:

```bash
OPENCLAW_ENABLE_HIMALAYA_SKILL=1 \
OPENCLAW_HIMALAYA_CONFIG_PATH="$OPENCLAW_CONFIG_DIR/himalaya/config.toml" \
OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64="$(base64 -w 0 /path/to/config.toml)" \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

This lets you inject credentials/config from your secret manager at runtime instead of running `himalaya account configure` interactively.

- `OPENCLAW_CODING_AGENT_REQUIRE_VERSION_CHECK` is retained for interface compatibility, but `<backend> --version` checks are not enforced during build.
## Coding-agent skill prerequisites

If you plan to use the coding-agent skill, enable prerequisite handling in the build:

```bash
OPENCLAW_ENABLE_CODING_AGENT_SKILL=1 \
OPENCLAW_CODING_AGENT_BACKEND=codex \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Supported backends (`OPENCLAW_CODING_AGENT_BACKEND`):

- `claude` → auto-install in container with `npm i -g @anthropic-ai/claude-code`
- `codex` → auto-install in container with `npm i -g @openai/codex`
- `pi` → auto-install in container with `npm i -g @mariozechner/pi-coding-agent`
- `opencode` → manual install required in container (script validates binary only)

Behavior when enabled:

- Auto-installs supported backends inside the running `openclaw` container:
  - `claude`: `npm i -g @anthropic-ai/claude-code`
  - `codex`: `npm i -g @openai/codex`
  - `pi`: `npm i -g @mariozechner/pi-coding-agent`
- `opencode` remains manual install.
- Validates that the selected backend binary is available inside the running `openclaw` container runtime after restart.
- By default (`OPENCLAW_CODING_AGENT_REQUIRE_VERSION_CHECK=1`), validates `<backend> --version` inside the running `openclaw` container runtime after restart.

Safety guidance:

- Do not run coding-agent commands against `~/.openclaw/...` paths.
- For Codex workflows, point `workdir` to a real git repo (or initialize one first).
