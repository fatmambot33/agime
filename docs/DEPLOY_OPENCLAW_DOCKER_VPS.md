# Deploy OpenClaw on a VPS (agime)

## Prerequisites

- Linux VPS with Docker + Docker Compose installed.
- SSH access from your workstation.
- OVH endpoint API key.

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

When `SKIP_OPENCLAW_WIZARD=1`, agime fails fast if `.env` is missing. Use this only after one successful wizard run (or when `.env` is already provisioned).

## Ongoing deployment sync

```sh
REMOTE_HOST=ubuntu@203.0.113.10 OVH_ENDPOINT_API_KEY=your-key sh ./sync.sh
```

`sync.sh` keeps local authoring and remote apply clearly separated: local upload first, remote execution second.
