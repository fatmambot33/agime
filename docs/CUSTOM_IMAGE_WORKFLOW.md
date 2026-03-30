# Custom OpenClaw Image Workflow (Agent-Enabled VPS)

This runbook provides a simple, repeatable process for building the custom image expected by this repository's image-first deployment model.

## Goals

- Keep VPS hosts thin (Docker + Compose + SSH + networking + bind mounts).
- Bake optional tools into the image (`gh`, `himalaya`, `codex`, `claude`, `opencode`, `pi`).
- If you use the `codex` coding-agent backend, also include `bwrap` (bubblewrap) in the image so sandboxed runs can start.
- Deploy with:
  - `OPENCLAW_IMAGE=<registry>/<name>:<tag>`
  - `SKIP_OPENCLAW_IMAGE_BUILD=1`

## Quick start (interactive first-time publish)

Use the guided entrypoint and select `Image`:

```sh
sh ./configure.sh
```

The workflow prompts for:

- GitHub user/org owner
- image name
- tag
- push preference

`configure.sh` normalizes owner and image name to lowercase so the computed GHCR reference is valid for Docker image tags.

Then it computes and displays:

```text
ghcr.io/<github-user-or-org>/<image-name>:<tag>
```

If push is enabled, it prints prerequisite authentication guidance before running:

- package publishing permissions for the chosen owner
- a token with package write scope
- `docker login ghcr.io` (for example via `--password-stdin`)

`Image` is intended for first-time bootstrap. `Update` remains the repeat maintenance path after your image workflow is established.

## Quick start (non-interactive)

From this repo root:

```sh
CUSTOM_OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:2026-03-26 \
sh ./scripts/build_custom_image.sh
```

Optional push:

```sh
CUSTOM_OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:2026-03-26 \
CUSTOM_OPENCLAW_PUSH=1 \
sh ./scripts/build_custom_image.sh
```

`scripts/build_custom_image.sh` requires `docker` in `PATH`.

If Docker is missing, the script attempts auto-install on Debian/Ubuntu hosts (`apt-get update && apt-get install -y docker.io docker-compose-v2`). On other distributions, install Docker manually before running the workflow.

The workflow also fails early if `docker` exists but the daemon/API is unreachable. On macOS/Windows, start Docker Desktop; on Linux, start the Docker service before retrying.

## Tunables

- `CUSTOM_OPENCLAW_IMAGE` (required): output image tag.
  - Must follow `ghcr.io/<owner>/<image-name>:<tag>`.
  - GHCR owner and image-name components must be lowercase.
- `CUSTOM_OPENCLAW_BASE_IMAGE` (default `ghcr.io/openclaw/openclaw:latest`): upstream/base OpenClaw image.
- For production, prefer a pinned base tag/digest over `:latest`.
- `CUSTOM_OPENCLAW_DOCKERFILE_TEMPLATE` (default `templates/openclaw-custom-image.Dockerfile.tmpl`).
- `CUSTOM_OPENCLAW_BROWSER_DEPS` (default `0`): set to `1` to install extra browser runtime deps.
- `CUSTOM_OPENCLAW_PUSH` (default `0`): set to `1` to push after successful build.

## Deploy with the built image

```sh
OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:2026-03-26 \
SKIP_OPENCLAW_IMAGE_BUILD=1 \
OPENCLAW_ACCESS_MODE=ssh-tunnel \
OVH_ENDPOINT_API_KEY=... \
sh ./build.sh
```

If you deploy through `sync.sh`, place the same values in `sync.conf`:

```sh
OPENCLAW_IMAGE=ghcr.io/<org>/ovhclaw:2026-03-26
SKIP_OPENCLAW_IMAGE_BUILD=1
OPENCLAW_ACCESS_MODE=ssh-tunnel
OVH_ENDPOINT_API_KEY=...
```

## Validation behavior after deploy

When optional features are enabled, `build.sh` validates tool binaries and basic `--version` calls in the running `openclaw` container. No host/runtime installer path is used.
