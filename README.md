# agime

Automation scripts for deploying OpenClaw on a VPS with two explicit access modes:

- `ssh-tunnel` (default, private access)
- `public` (Traefik + Let's Encrypt, explicit opt-in)

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `build-interactive.sh`: guided wrapper that collects inputs and runs `build.sh`.
- `sync.sh`: helper to copy setup scripts plus required `scripts/` and `templates/` dependencies over SSH, then run setup remotely.
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
sh -n build.sh build-interactive.sh sync.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh
```
