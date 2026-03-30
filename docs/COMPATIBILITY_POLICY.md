# Compatibility and Testing Policy

Date: 2026-03-30

## Runtime compatibility scope

This toolkit is maintained for Linux VPS deployments with Docker + Docker Compose.

Minimum assumptions:

- POSIX `sh` available.
- Docker CLI + Compose plugin available on target host.
- SSH + SCP available on workstation for `sync.sh` flows.

## Compatibility matrix policy

- Keep compatibility statements in this file and update on release.
- Include at least:
  - tested Ubuntu LTS baseline,
  - tested Docker/Compose baseline,
  - notable caveats for root vs non-root execution paths.

## Testing policy per release

Every release candidate must pass:

- `make check-strict`
- CI workflow (`.github/workflows/ci.yml`)

If compatibility assumptions change, update in same PR:

- `README.md`
- `docs/DEPLOY_OPENCLAW_DOCKER_VPS.md`
- `docs/OPERATIONS.md`
- this file
