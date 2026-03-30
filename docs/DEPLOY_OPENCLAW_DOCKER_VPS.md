# Deploy OpenClaw on a VPS (agime)

## Prerequisites

- Linux VPS with Docker + Docker Compose installed.
- SSH access from your workstation.
- OVH endpoint API key.

## Setup plan (OVH VPS)

1. Collect required OVH inputs up front:
   - `OVH_ENDPOINT_API_KEY`
   - `OPENCLAW_ACCESS_MODE` (`ssh-tunnel` or `public`)
   - `public` mode only: `OPENCLAW_DOMAIN` and `TRAEFIK_ACME_EMAIL`
2. Ensure outbound network access from the VPS so agime can install Docker and `docker compose` automatically when missing.
   - If the current user cannot access Docker yet, agime will continue the current run with `sudo docker` and add the user to the `docker` group for future sessions.
3. Choose OpenClaw image policy:
   - fixed official image: `ghcr.io/openclaw/openclaw:latest`
4. Keep Traefik only for `OPENCLAW_ACCESS_MODE=public` (ssh-tunnel mode skips Traefik).
5. Run `sh ./setup.sh`; on first deploy, OpenClaw wizard (`./docker-setup.sh`) runs when `.env` is missing.
6. Validate endpoint access:
   - `ssh-tunnel`: local tunnel to `127.0.0.1:18789`
   - `public`: HTTPS via `https://$OPENCLAW_DOMAIN`

## Recommended private deployment (`ssh-tunnel`)

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
sh ./setup.sh
```

`REMOTE_DIR` is interpreted as a remote-home path (`~/...`). If your local shell expands it before invoking the script, agime normalizes it back to `~/...` automatically.

Then tunnel locally:

```sh
ssh -N -L 18789:127.0.0.1:18789 ubuntu@203.0.113.10
```

Open: `http://127.0.0.1:18789`

## Public deployment (`public`, explicit opt-in)

```sh
REMOTE_HOST=ubuntu@203.0.113.10 \
REMOTE_DIR=~/agime \
OVH_ENDPOINT_API_KEY=your-key \
OPENCLAW_ACCESS_MODE=public \
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
sh ./setup.sh
```

Open: `https://openclaw.example.com`

## First-run behavior (`build.sh` on remote host)

On first run, if `OPENCLAW_DIR/.env` is missing, agime runs OpenClaw's `./docker-setup.sh` wizard.

This wizard step is required for installs; skipping the wizard is not supported.

## Ongoing deployment sync

```sh
REMOTE_HOST=ubuntu@203.0.113.10 OVH_ENDPOINT_API_KEY=your-key sh ./sync.sh
```

`sync.sh` keeps local authoring and remote apply clearly separated: local upload first, remote execution second.

By default, `sync.sh` transfers only the minimal files needed for the selected remote entrypoint (`build.sh`, `update.sh`, `backup.sh`, or `restore.sh`). For mode-specific templates, it reads `OPENCLAW_ACCESS_MODE` from shell env or `SYNC_LOCAL_ENV_FILE`. Set `SYNC_ITEMS` when you need a custom/full payload.
