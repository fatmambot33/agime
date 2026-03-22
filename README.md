# agime

Automation scripts for deploying an OpenClaw gateway behind Traefik on a VPS.

## Current repository contents

- `build.sh`: non-interactive end-to-end setup script (environment-variable driven).
- `build-interactive.sh`: guided wrapper that collects inputs and runs `build.sh`.
- `sync.sh`: minimal helper to copy and run setup scripts over SSH.

## Quick start

```bash
chmod +x build.sh
TRAEFIK_ACME_EMAIL=admin@example.com \
OPENCLAW_DOMAIN=openclaw.example.com \
OVH_ENDPOINT_API_KEY=xxxxx \
./build.sh
```

Or use the interactive setup:

```bash
chmod +x build-interactive.sh
./build-interactive.sh
```

## Required tooling

- Docker with Docker Compose support (`docker compose`)
- Git
- Sudo access on the target host

## Documentation

- [Agent operating guide](AGENTS.md)
- [Repository review](docs/REPO_REVIEW.md)
- [Follow-up evolution plan](docs/FOLLOW_UP_PLAN.md)
- [Contributing conventions](docs/CONTRIBUTING.md)
