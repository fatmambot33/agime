# Compatibility and Testing Policy

Date: 2026-03-30

## Runtime compatibility scope

This toolkit is maintained for OVH VPS deployments on Ubuntu LTS with Docker + Docker Compose.

Minimum assumptions:

- POSIX `sh` available.
- Docker CLI + Compose plugin available on target host.
- SSH + SCP available on workstation for `sync.sh` flows.

Primary baseline (runtime):

- OVH VPS running Ubuntu 24.04 LTS (or newer Ubuntu LTS explicitly called out in release notes).

Contributor baseline (local tooling):

- CI is authoritative on Ubuntu runners.
- macOS and other Linux distributions are best-effort for local test runs.

## Compatibility matrix policy

- Keep compatibility statements in this file and update on release.
- Include at least:
  - tested OVH Ubuntu LTS runtime baseline,
  - tested Docker/Compose baseline,
  - notable caveats for root vs non-root execution paths and local contributor portability.

## Testing policy per release

Every release candidate must pass:

- `make check-strict`
- CI workflow (`.github/workflows/ci.yml`)

If compatibility assumptions change, update in same PR:

- `README.md`
- `docs/DEPLOY_OPENCLAW_DOCKER_VPS.md`
- `docs/OPERATIONS.md`
- this file
