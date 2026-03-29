# Deploy OpenClaw with Docker on a VPS (Recommended)

This guide standardizes the production-style deployment model for this toolkit.

## Deployment contract

This repository composes upstream OpenClaw Docker setup into an opinionated VPS workflow:

- `ssh-tunnel` is the default and recommended access mode (private-by-default).
- `public` mode is explicitly supported through Traefik + Let's Encrypt.
- Docker is the required runtime boundary on the VPS host.
- Optional agent tooling is expected inside your selected `OPENCLAW_IMAGE`, not installed ad hoc on the VPS.

### Native mode behavior (easy path)

- In `ssh-tunnel` mode, the stack runs without Traefik and stays private behind SSH forwarding.
- In `public` mode, Traefik is added automatically by the toolkit templates/scripts for HTTPS ingress.
- Keep mode selection explicit in `sync.conf` with `OPENCLAW_ACCESS_MODE=ssh-tunnel|public`.

### Model selection (including premium models)

This toolkit writes `openclaw.json` in `models.mode=merge`, so your selected OVH model is appended into provider/agent defaults during setup.

- Set `OVH_ENDPOINT_MODEL=<model-id>` in `sync.conf` (or env) before deploy.
- If you do not set `OVH_ENDPOINT_MODEL`, the toolkit uses its current OVH default (`gpt-oss-120b`) as the baseline model.
- You can choose premium OVH models here when your endpoint/account allows them.
- During factory/setup flow, keep the same model id so runtime config and defaults stay aligned.

## Machine boundaries

### Local workstation responsibilities

- Author and update deployment config (`sync.conf`) via `configure.sh` or direct editing.
- Reconcile/upload runtime bundle to the VPS via `sync.sh`.
- Choose whether remote execution should run `build.sh` (default) or `configure.sh`.

### VPS responsibilities

- Run Docker Engine + Docker Compose v2.
- Execute deployment changes with `build.sh` (normally triggered by `sync.sh`).
- Persist runtime data under configured bind mounts (`OPENCLAW_CONFIG_DIR`, workspace, optional Traefik state).

## End-to-end flow

1. **Prepare VPS host**
   - Install and verify Docker Engine + Compose v2.
   - Ensure SSH access from your workstation.
   - For `public` mode, ensure DNS points to the VPS and inbound `80/443` are open.

2. **Author deployment config locally**
   - Copy `sync.conf.example` to `sync.conf` and set required values.
   - Required for OVH-backed endpoint provisioning: `OVH_ENDPOINT_API_KEY`.
   - Decide `OPENCLAW_ACCESS_MODE` (`ssh-tunnel` recommended; `public` explicit opt-in).

3. **Use image-first deployment settings**
   - Pin a prebuilt image with optional tools baked in.
   - Keep runtime immutable by setting:

   ```sh
   OPENCLAW_IMAGE=<registry>/<name>:<tag>
   SKIP_OPENCLAW_IMAGE_BUILD=1
   ```

4. **Deploy remotely**

   ```sh
   REMOTE_HOST=<user>@<vps-host> \
   REMOTE_DIR=~/agime \
   sh ./sync.sh
   ```

   By default, `sync.sh` uploads the runtime bundle and executes remote `build.sh`.

5. **Validate post-deploy behavior**
   - `ssh-tunnel`: verify local tunnel + `http://127.0.0.1:18789`.
   - `public`: verify `https://<OPENCLAW_DOMAIN>` and inspect Traefik/OpenClaw logs if TLS is still settling.

6. **Operate safely over time**
   - Take backups before change windows (`sh ./backup.sh`).
   - Use `sh ./update.sh` for toolkit refresh + redeploy flow.
   - Use `sh ./restore.sh` for rollback/recovery (sandbox restore first, root restore only with explicit force).

## Supported access modes

### `ssh-tunnel` (default)

- Private-by-default deployment posture.
- OpenClaw binds to loopback on VPS (`127.0.0.1:18789`).
- Operator reaches service through SSH local forwarding.

### `public` (explicit)

- Domain-based HTTPS via Traefik and Let's Encrypt.
- Requires reliable DNS and inbound `80/443`.
- Keep this mode as an explicit risk/operational choice.

## Why this differs from upstream bootstrap docs

Upstream Docker guidance is a starting point. This toolkit adds VPS operational policy:

- sync-driven remote deployment model (`sync.sh` + remote `build.sh`),
- explicit access-mode policy with private default,
- Traefik orchestration for public ingress,
- deterministic post-build validation,
- image-first optional-tool strategy,
- backup/restore/update helpers for auditable operations.

## Operator outcomes

After following this model, operators should be able to:

- prepare a VPS for Docker-based OpenClaw deployment,
- choose an access mode based on risk posture,
- deploy with clear local-vs-remote responsibility boundaries,
- run pinned prebuilt images for agent-enabled workflows,
- validate health and recover safely when changes fail.
