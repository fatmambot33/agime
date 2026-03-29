# OpenClaw VPS Deployment (Docker, Pure Flow)

## Required contract

- VPS runtime: Docker Engine + Docker Compose v2.
- Access mode: `ssh-tunnel` (default) or `public` (explicit).
- OVH endpoint: `OVH_ENDPOINT_API_KEY` is mandatory.
- Model: `OVH_ENDPOINT_MODEL` optional, defaults to `gpt-oss-120b`.
- Image runtime: use pinned `OPENCLAW_IMAGE` with `SKIP_OPENCLAW_IMAGE_BUILD=1`.
- Optional tools must exist inside the selected image, not on the host.

## Native bootstrap rule

- First install must use native OpenClaw factory bootstrap:
  - keep `SKIP_OPENCLAW_WIZARD=0` (default).
- After bootstrap is complete, automation can use:
  - `SKIP_OPENCLAW_WIZARD=1`.

## Interactive deployment path (recommended)

Use the interactive entrypoint to follow the native flow with prompts:

```sh
REMOTE_HOST=<user>@<vps-host> \
REMOTE_DIR=~/agime \
sh ./setup.sh
```

Interactive flow asks for required values (including OVH key, access mode, and domain/email when `public`) and then runs remote deployment through `sync.sh` + `build.sh`.

## Minimal deployment steps

1. Prepare VPS
   - Docker/Compose available.
   - SSH reachable.
   - If `public`: DNS + inbound `80/443` ready.

2. Prepare local config (`sync.conf`)
   - Set `OVH_ENDPOINT_API_KEY`.
   - Optionally set `OVH_ENDPOINT_MODEL`.
   - Set `OPENCLAW_ACCESS_MODE=ssh-tunnel|public`.
   - Set image-first values:

   ```sh
   OPENCLAW_IMAGE=<registry>/<name>:<tag>
   SKIP_OPENCLAW_IMAGE_BUILD=1
   ```

3. Deploy (non-interactive alternative)

   ```sh
   REMOTE_HOST=<user>@<vps-host> \
   REMOTE_DIR=~/agime \
   sh ./sync.sh
   ```

4. Validate
   - `ssh-tunnel`: open SSH tunnel, check `http://127.0.0.1:18789/healthz`.
   - `public`: check `https://<OPENCLAW_DOMAIN>` and `docker logs traefik`.

5. Operate safely
   - Backup: `sh ./backup.sh`
   - Update: `sh ./update.sh`
   - Restore: `sh ./restore.sh`

## Mode behavior

### `ssh-tunnel`
- Private path, no Traefik.
- OpenClaw bound to `127.0.0.1:18789`.

### `public`
- Traefik is added by toolkit templates/scripts.
- HTTPS through Let's Encrypt.
