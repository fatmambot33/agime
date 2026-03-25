# Compatibility Matrix (OVH VPS / Ubuntu)

Last reviewed: 2026-03-25

This toolkit targets Ubuntu-based OVH VPS hosts and Docker Engine deployments.

## Validated baseline

| Component | Recommended | Minimum | Notes |
|---|---:|---:|---|
| Ubuntu | 24.04 LTS | 22.04 LTS | LTS-only baseline for predictable package lifecycle. |
| Docker Engine | 26.x | 24.x | Must support Compose plugin v2. |
| Docker Compose plugin (`docker compose`) | 2.24+ | 2.20+ | Required by `build.sh` and compose templates. |
| OpenClaw image/runtime | `openclaw:local` from repo checkout | N/A | Built locally from synced checkout. |
| Traefik | v3 (as rendered by template) | v3 | Used only in `OPENCLAW_ACCESS_MODE=public`. |

## Host profile assumptions

- VPS provider: OVH (public IPv4 reachable from your workstation).
- OS user has sudo rights for package install / Docker setup.
- DNS control available when using `OPENCLAW_ACCESS_MODE=public`.
- Ports:
  - `22/tcp` for SSH always.
  - `80/tcp` + `443/tcp` only when `public` mode is enabled.

## Operator checks before first deploy

Run these directly on the VPS:

```sh
uname -a
. /etc/os-release && printf '%s %s\n' "$NAME" "$VERSION_ID"
docker --version
docker compose version
```

Expected outcomes:

- Ubuntu LTS version is `22.04` or `24.04`.
- Docker Engine and Compose plugin are installed.
- `docker compose version` succeeds (plugin path present).

## Ongoing maintenance cadence

- Monthly:
  - `sudo apt update && sudo apt upgrade -y`
  - `docker system prune` (with change window and backup in place)
- Before any toolkit upgrade:
  - Run `backup.sh` and verify archive readability.
  - Re-run `make check` in your local checkout before syncing.
- After deploy/update:
  - Validate health endpoint behavior for your selected access mode.
  - Review `docker logs openclaw` (and `docker logs traefik` in public mode).

## Notes on support posture

- Non-LTS Ubuntu and distro variants are not primary targets.
- The toolkit can still work beyond this matrix, but those paths should be validated in a staging VPS before production rollout.
