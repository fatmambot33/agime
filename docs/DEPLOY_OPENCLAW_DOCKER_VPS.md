# Standard VPS Deployment (Docker)

Use this standard flow to deploy OpenClaw on a VPS.

## 1) Quick start

Interactive (recommended):

```sh
REMOTE_HOST=<user>@<vps-host> REMOTE_DIR=~/agime sh ./setup.sh
```

Non-interactive:

```sh
REMOTE_HOST=<user>@<vps-host> REMOTE_DIR=~/agime sh ./sync.sh
```

## 2) Required settings

- `OVH_ENDPOINT_API_KEY` is required.
- `OPENCLAW_ACCESS_MODE` is `ssh-tunnel` (default) or `public`.
- `OVH_ENDPOINT_MODEL` is optional (default: `gpt-oss-120b`).

## 3) Optional image setting

A custom image is optional.

```sh
OPENCLAW_IMAGE=<registry>/<name>:<tag>
SKIP_OPENCLAW_IMAGE_BUILD=1
```

If unset, the default local image flow (`openclaw:local`) is used.

## 4) Validation

- `ssh-tunnel`: check `http://127.0.0.1:18789/healthz`
- `public`: check `https://<OPENCLAW_DOMAIN>` and `docker logs traefik`

## 5) Safe operations

- Backup: `sh ./backup.sh`
- Update: `sh ./update.sh`
- Restore: `sh ./restore.sh`
