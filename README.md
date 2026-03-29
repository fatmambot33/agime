# agime

Automation scripts for deploying OpenClaw on a VPS with two explicit access modes:

- `ssh-tunnel` (default, private access)
- `public` (Traefik + Let's Encrypt, explicit opt-in)

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `configure.sh`: guided entrypoint with a welcome menu (`Image`, `Install`, `Update`, `Add Tool`, `Backup`, `Restore`, `Security`); `Install` collects inputs then runs `build.sh`.
- `sync.sh`: local helper that reconciles `sync.conf`, uploads the runtime deployment bundle to a VPS, then runs remote deployment (`build.sh`) by default (set `SYNC_REMOTE_ENTRYPOINT=configure.sh` to use the remote welcome menu intentionally).
- `sync.conf.example`: sample local config file for `sync.sh` (copy to `sync.conf` to track current sync/build defaults).
- `.sync-build.env.example`: sample build environment file for non-interactive deploy runs.
- `backup.sh`: creates a tarball backup of OpenClaw runtime data (`$OPENCLAW_CONFIG_DIR`, `$OPENCLAW_DIR/.env`, optional Traefik state).
- `update.sh`: post-install helper that can fast-forward pull this toolkit checkout (auto-detected) and rerun `build.sh`.
- `image.sh`: top-level helper for custom image build/push workflow (wrapper around `scripts/build_custom_image.sh`).
- `add_tool.sh`: post-install helper to enable one optional tool and rerun `build.sh`; setup 2.0 generally prefers baking tooling into the image.
- `restore.sh`: restores a backup tarball into a chosen root path (requires explicit force flag for `/`).
- `setup.sh`: simplest setup entrypoint; it forwards into the existing `configure.sh` Install flow (local) or `sync.sh` + remote Install flow (when `REMOTE_HOST` is set).
- `scripts/build_lib.sh` + `scripts/build_steps.sh`: shared helpers and modular deployment steps used by `build.sh`.
- `scripts/optional_tools/*.sh`: per-tool optional runtime handlers (GitHub, Himalaya, coding-agent) plus shared container validation helpers.
- `scripts/build_custom_image.sh`: helper to build/push a prebuilt custom OpenClaw image with optional tooling baked in.
- `templates/openclaw-compose.ssh-tunnel.yml.tmpl`: private/local compose template.
- `templates/openclaw-compose.public.yml.tmpl`: Traefik-integrated compose template.
- `templates/traefik-compose.yml.tmpl`: Traefik compose template (public mode only).
- `templates/openclaw.json.tmpl`: OpenClaw JSON config template.
- `templates/openclaw-custom-image.Dockerfile.tmpl`: starter Dockerfile template used by `scripts/build_custom_image.sh`.
- `Makefile`: local quality checks.
- `docs/COMPATIBILITY_MATRIX.md`: OVH Ubuntu compatibility baseline and version expectations.
- `docs/CUSTOM_IMAGE_WORKFLOW.md`: step-by-step custom image build/push/deploy workflow.

## Quick start

### Default easy setup (`setup.sh`)

`setup.sh` is now a streamlined OVH-oriented installer:

- prompts for required OVH + access-mode values;
- runs template-based `build.sh`.

Mode behavior:

- choose `ssh-tunnel` to keep OpenClaw private (default);
- choose `public` to enable Traefik + HTTPS routing.

Run:

```bash
sh ./setup.sh
```

Use `configure.sh` when you want the full toolkit menu (`Image`, `Install`, `Update`, `Add Tool`, `Backup`, `Restore`, `Security`).

### Sync + remote deploy

Run from your local machine:

```bash
REMOTE_HOST=<user>@<host> sh ./sync.sh
```

Behavior:

- sync/upload is executed locally;
- non-interactive deploy (`build.sh`) is executed on the SSH host by default.

`sync.sh` now enables SSH connection multiplexing by default (`ControlMaster=auto` + `ControlPersist`), which usually avoids repeated password prompts across the multiple SSH/SCP calls.

Tune if needed:

```bash
SSH_CONTROL_PERSIST_SECONDS=1200 \
SSH_CONTROL_PATH="$HOME/.ssh/agime-sync-%r@%h:%p" \
REMOTE_HOST=<user>@<host> \
sh ./sync.sh
```

Use a local config file (so current sync + build settings are visible and reusable):

```bash
# optional: pre-create/edit; otherwise sync.sh will recover/bootstrap it
$EDITOR ./sync.conf
sh ./sync.sh
```

`sync.sh` auto-loads `./sync.conf` when present.
It then prioritizes an existing remote env file (`SYNC_REMOTE_ENV_FILE`, default `sync.conf`): when found, that remote file is downloaded locally and used as the source of truth for the run.
If the remote file is missing, `sync.sh` uses local config; and when local is also missing, it runs local `configure.sh` in config-generation mode to create one, then appends `REMOTE_HOST`/`REMOTE_DIR` if absent.
When `sync.sh` creates/downloads that shared config, it normalizes `OPENCLAW_*`/`TRAEFIK_DIR` home paths to `~/...` form so `sync.conf` stays portable across workstation + VPS homes.
By default, the same `sync.conf` is sourced remotely before execution (`SYNC_REMOTE_ENV_FILE=sync.conf`) under `set -a`, so plain `KEY=value` assignments are auto-exported for the selected remote entrypoint.
When `SYNC_REMOTE_ENV_FILE` points to the same file already included in `SYNC_ITEMS` (default: `sync.conf`), `sync.sh` uploads it once to avoid duplicate transfer lines.
When `configure.sh` is launched from `sync.sh`, values already present in `sync.conf` are reused as prompt defaults (for example `OPENCLAW_ACCESS_MODE`, directories, and optional tool flags), so pressing Enter keeps existing config values.
Set `SYNC_PRINT_CONFIG=1` to print the effective config before execution.
`sync.conf` is intentionally gitignored (it may contain secrets), while `sync.conf.example` remains the safe template.

Single-file non-interactive remote deploy (`build.sh`) example:

```bash
$EDITOR ./sync.conf
sh ./sync.sh
```

Set this in `sync.conf`:

- add required `build.sh` variables directly to `sync.conf` (for example `OVH_ENDPOINT_API_KEY=...`, optional access-mode settings). They can remain plain shell assignments; `sync.sh` auto-exports them on the remote host before launching `build.sh`.
- `sync.sh` now prints a preflight warning when `SYNC_REMOTE_ENTRYPOINT=build.sh` and `OVH_ENDPOINT_API_KEY` is empty in loaded config/environment.
- `SYNC_REMOTE_CONFIG_PRIORITY=1` (default) keeps remote env authoritative when it already exists; set `SYNC_REMOTE_CONFIG_PRIORITY=0` if you explicitly want to push local config as the source of truth.

If you prefer the welcome flow and want those selections reflected in reusable config:

- set `SYNC_REMOTE_ENTRYPOINT=configure.sh`;
- keep `SYNC_REMOTE_ENV_FILE=sync.conf` (default);
- set `SYNC_MIRROR_ENV_FILE=1` when you want remote updates copied back locally.

With this, `configure.sh` can write updated values on the remote host and `sync.sh` copies the remote env file back locally (chmod `600`) so your local `sync.conf` stays current.

`configure.sh` also checks for `./.sync-build.env` on the host by default; when present, it skips prompts and runs `build.sh` directly. Set `OPENCLAW_FORCE_INTERACTIVE=1` to force the menu/prompts.

### Machine boundary and remote footprint

- **Local workstation:** run `configure.sh` to author/update config and run `sync.sh` to reconcile and upload files.
- **Remote VPS:** run `build.sh` (or other selected entrypoint) to apply deployment changes.
- Default upload payload is runtime-only: `build.sh backup.sh update.sh image.sh restore.sh scripts templates docs README.md` (plus `sync.conf` when needed).
- Local authoring helpers are intentionally excluded from default payload; override with `SYNC_ITEMS` only when you explicitly need a different bundle.

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

## Image-first deployment model (recommended)

Use a prebuilt custom image that already contains optional tools used by your agent workflows.

Recommended settings:

```bash
OPENCLAW_IMAGE=ghcr.io/<org>/<openclaw-image>:<tag> \
SKIP_OPENCLAW_IMAGE_BUILD=1 ./build.sh
```

`build.sh` still supports local rebuilds (`SKIP_OPENCLAW_IMAGE_BUILD=0`) for migration scenarios, but production-like VPS deployments should prefer image-first with immutable tags.

Standard VPS deployment contract:

```bash
OPENCLAW_IMAGE=<registry>/<name>:<tag> \
SKIP_OPENCLAW_IMAGE_BUILD=1 \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
OVH_ENDPOINT_API_KEY=... \
./build.sh
```

Host responsibilities are intentionally limited to Docker Engine, Docker Compose v2, SSH access, firewall/networking, and persistent bind mounts. Optional tools (`gh`, `himalaya`, `codex`, `claude`, `opencode`, `pi`, `signal-cli`) must be present in the selected `OPENCLAW_IMAGE`.

## Build your custom image (easy path)

For first-time publishing, use the interactive workflow:

```bash
sh ./configure.sh
# choose: Image
```

The `Image` action now walks through:

- GitHub owner (`ghcr.io/<owner>/...`)
- image name (`ghcr.io/<owner>/<image-name>:...`)
- tag (`ghcr.io/<owner>/<image-name>:<tag>`)
- whether to push after build

Owner and image-name inputs are normalized to lowercase automatically so the generated GHCR reference is always Docker-compatible.

Then it prints the exact computed image reference before running the build:

```text
ghcr.io/<github-user-or-org>/ovhclaw:<tag>
```

If push is enabled, it also explains GHCR auth prerequisites (`docker login ghcr.io` with package write permissions) before attempting a push.

Advanced/non-interactive usage remains available via direct environment variables:

```bash
CUSTOM_OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:<tag> \
sh ./scripts/build_custom_image.sh
```

`scripts/build_custom_image.sh` requires `docker` to be available on the host. If Docker is missing, the script attempts automatic installation on Debian/Ubuntu; on other hosts, install Docker Engine manually before running the image workflow. The script also checks that the Docker daemon/API is reachable before build (for example, start Docker Desktop on macOS/Windows, or start the Docker service on Linux).
The script also validates `CUSTOM_OPENCLAW_IMAGE` format (`ghcr.io/<owner>/<image-name>:<tag>`) and fails early if owner/image contain uppercase characters.

Tip: for production builds, pin your base OpenClaw image tag/digest instead of relying on `:latest` (set `CUSTOM_OPENCLAW_BASE_IMAGE=...`).

Push in the same step:

```bash
CUSTOM_OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:<tag> \
CUSTOM_OPENCLAW_PUSH=1 \
sh ./scripts/build_custom_image.sh
```

Then deploy with:

```bash
OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:<tag> \
SKIP_OPENCLAW_IMAGE_BUILD=1 \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
OVH_ENDPOINT_API_KEY=... \
sh ./build.sh
```

Advanced options and tunables are documented in `docs/CUSTOM_IMAGE_WORKFLOW.md`.

For `sync.sh` users, add this to `sync.conf`:

```bash
OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:<tag>
SKIP_OPENCLAW_IMAGE_BUILD=1
OPENCLAW_ACCESS_MODE=ssh-tunnel
OVH_ENDPOINT_API_KEY=...
```

## Post-build connectivity validation

Enabled by default (`POST_BUILD_TEST=1`). Tunables:

- `POST_BUILD_TEST_ATTEMPTS` (default `40`)
- `POST_BUILD_TEST_DELAY_SECONDS` (default `3`)
- `POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS` (default `5`)
- `POST_BUILD_TEST_MAX_TIME_SECONDS` (default `15`)

Public-mode retry logic treats temporary default/self-signed cert states as transient while ACME issuance finishes.

## Signal channel setup (optional)

This toolkit preconfigures `channels.signal` in `openclaw.json` and validates `signal-cli` inside the running container.

```bash
OPENCLAW_ENABLE_SIGNAL=1 \
OPENCLAW_SIGNAL_ACCOUNT=+15551234567 \
OPENCLAW_SIGNAL_ALLOW_FROM=+15557654321 \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Behavior:

- When `OPENCLAW_ENABLE_SIGNAL=1`, the script validates `signal-cli` is available inside the running `openclaw` container.
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
sh -n build.sh configure.sh sync.sh backup.sh update.sh add_tool.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/configure_backup_hermetic.sh tests/configure_autoload_env_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh
```

## Backup and restore mechanic

`configure.sh` includes an explicit pre-deploy backup prompt (enabled by default unless `DRY_RUN=1`) so you can capture a restore point before changes are applied.

Backup defaults:
- Includes `$OPENCLAW_CONFIG_DIR` (default `$HOME/.openclaw`).
- Includes `OPENCLAW_WORKSPACE_DIR` (default `$OPENCLAW_CONFIG_DIR/workspace`) so workspace data is captured even when moved outside `$OPENCLAW_CONFIG_DIR`.
- Includes `OPENCLAW_SKILLS_DIR` (default `$OPENCLAW_CONFIG_DIR/skills`) and `OPENCLAW_HOOKS_DIR` (default `$OPENCLAW_CONFIG_DIR/hooks`) when present.
- Includes `OPENCLAW_PAIRED_DEVICES_PATH` (default `$OPENCLAW_CONFIG_DIR/paired-devices.json`) when present.
- Includes `$OPENCLAW_DIR/.env` (default `$HOME/openclaw/.env`).
- Includes `$OPENCLAW_DIR/docker-compose.yml` when present.
- Excludes Traefik data by default unless `INCLUDE_TRAEFIK=1`.
- Excludes full OpenClaw git checkout by default unless `INCLUDE_OPENCLAW_REPO=1`.
- Supports additional paths via `EXTRA_BACKUP_PATHS` (space-separated).

During deploy, when `openclaw.json` already exists, `build.sh` now writes timestamped backups to `OPENCLAW_JSON_BACKUP_DIR` (default `$HOME/openclaw-backups`) instead of writing `.bak` files inside `$OPENCLAW_CONFIG_DIR`.

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

`restore.sh` also validates archive entry paths and refuses extraction when unsafe entries (absolute paths or `..` traversal segments) are detected.

## Post-install helpers

Create a backup before maintenance changes:

```bash
sh ./backup.sh
```

Update this toolkit checkout and rerun deployment (works in both a git clone and synced `/tmp/agime` copy):

```bash
sh ./update.sh
```

`update.sh` now runs an easy maintenance flow by default:

1) create a pre-update backup archive,  
2) auto-load `./.sync-build.env` when present,  
3) pull `OPENCLAW_IMAGE` when `SKIP_OPENCLAW_IMAGE_BUILD=1` (image-first mode),  
4) run `build.sh` to deploy, validate optional tools, and apply changes.

Safety guard: when backup is enabled, `update.sh` now verifies the backup archive file was actually created before continuing.

Control pull behavior explicitly when needed:

```bash
GIT_PULL=1 sh ./update.sh      # require git checkout and pull
GIT_PULL=0 sh ./update.sh      # skip pull and only rerun build
LOAD_DEPLOY_ENV=0 sh ./update.sh  # ignore .sync-build.env for this run
RUN_BACKUP=0 sh ./update.sh    # skip automatic pre-update backup
RUN_IMAGE_PULL=0 sh ./update.sh  # skip docker pull
RESTORE_ON_FAILURE=1 sh ./update.sh  # auto-restore backup if build fails
```

Optional helper (setup 2.0 usually does not need this): enable one optional tool after initial install (example: GitHub CLI runtime support):

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

- Validates that `gh` is available inside the running `openclaw` container runtime after restart.
- Assumes `gh` is already baked into your custom `OPENCLAW_IMAGE`.
- Prints a post-build reminder to run `gh auth login` / `gh auth status` in the running container before using the GitHub skill.

Image-first note: this repo does not install `gh` at runtime. Bake `gh` into your custom `OPENCLAW_IMAGE`, then authenticate in-container as needed (`gh auth login`).

## Himalaya skill prerequisites

If you plan to use the OpenClaw Himalaya skill, enable prerequisite handling in the build:

```bash
OPENCLAW_ENABLE_HIMALAYA_SKILL=1 \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Behavior when enabled:

- Validates that `himalaya` is available inside the running `openclaw` container runtime after restart.
- Assumes `himalaya` is already baked into your custom `OPENCLAW_IMAGE`.
- If `OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64` is set, the script writes that content to `OPENCLAW_HIMALAYA_CONFIG_PATH` with `chmod 600`.
- Validates config presence by default (`OPENCLAW_HIMALAYA_REQUIRE_CONFIG=1`) at `OPENCLAW_HIMALAYA_CONFIG_PATH` (default `$OPENCLAW_CONFIG_DIR/himalaya/config.toml`).
- Mounts `${OPENCLAW_CONFIG_DIR}/himalaya` into the container as `/home/node/.config/himalaya`.

Image-first note: this repo does not install `himalaya` at runtime. Bake it into your custom `OPENCLAW_IMAGE`, and keep config at `${OPENCLAW_CONFIG_DIR}/himalaya/config.toml` (or inject via `OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64`).

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
## Coding-agent skill prerequisites

If you plan to use the coding-agent skill, enable prerequisite handling in the build:

```bash
OPENCLAW_ENABLE_CODING_AGENT_SKILL=1 \
OPENCLAW_CODING_AGENT_BACKEND=codex \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Supported backends (`OPENCLAW_CODING_AGENT_BACKEND`):

- `claude`
- `codex`
- `pi`
- `opencode`

Behavior when enabled:

- Validates the selected backend binary inside the running `openclaw` container runtime after restart.
- For `OPENCLAW_CODING_AGENT_BACKEND=codex`, also validates `bwrap` (bubblewrap) inside the running container runtime because Codex sandboxing depends on it.
- Assumes backend binaries are already baked into your custom `OPENCLAW_IMAGE`.
- Validates `<backend> --version` inside the running `openclaw` container runtime after restart.

Safety guidance:

- Do not run coding-agent commands against `~/.openclaw/...` paths.
- For Codex workflows, point `workdir` to a real git repo (or initialize one first).
