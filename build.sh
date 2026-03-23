#!/usr/bin/env sh

set -eu

SCRIPT_NAME=$(basename "$0")

log() {
 printf '%s\n' "$*"
}

fail() {
 printf 'Error: %s\n' "$*" >&2
 exit 1
}

usage() {
 cat <<EOF
Usage:
 TRAEFIK_ACME_EMAIL=admin@example.com \\
 OPENCLAW_DOMAIN=openclaw.example.com \\
 OVH_ENDPOINT_API_KEY=xxxxx \\
 sh $SCRIPT_NAME

Required environment variables:
 TRAEFIK_ACME_EMAIL Email used by Let's Encrypt / Traefik.
 OPENCLAW_DOMAIN Public domain that points to the VPS.
 OVH_ENDPOINT_API_KEY OVHcloud AI Endpoints API key.

Optional environment variables:
 OPENCLAW_TOKEN Reuse an existing OpenClaw gateway token.
 OPENCLAW_DIR Default: \$HOME/openclaw
 OPENCLAW_CONFIG_DIR Default: \$HOME/.openclaw
 OPENCLAW_WORKSPACE_DIR Default: \$HOME/.openclaw/workspace
 TRAEFIK_DIR Default: \$HOME/docker/traefik
 OPENCLAW_REPO Default: https://github.com/openclaw/openclaw.git
 OPENCLAW_IMAGE Default: openclaw:local
 OPENCLAW_GATEWAY_BIND Default: lan
 OVH_ENDPOINT_BASE_URL Default: https://oai.endpoints.kepler.ai.cloud.ovh.net/v1
 OVH_ENDPOINT_MODEL Default: gpt-oss-120b
 OPENCLAW_USER Default: current user
 SKIP_DOCKER_GROUP_SETUP Default: 0. Set to 1 to skip docker group changes.
 SKIP_OPENCLAW_WIZARD Default: 0. Set to 1 if .env already exists.
 DRY_RUN Default: 0. Set to 1 to print planned actions without applying changes.

Notes:
 - This script automates the OVHcloud guide published on 2026-02-25:
 https://help.ovhcloud.com/csm/fr-vps-install-openclaw?id=kb_article_view&sysparm_article=KB0074788
 - Docker and Docker Compose must already be installed.
 - If the OpenClaw setup wizard runs, it remains interactive.
EOF
}

require_command() {
 command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_env() {
 var_name=$1
 eval "var_value=\${$var_name-}"
 [ -n "$var_value" ] || fail "Environment variable $var_name is required"
}

run_cmd() {
 if [ "$DRY_RUN" = "1" ]; then
 log "[DRY_RUN] $*"
 return 0
 fi
 "$@"
}

write_file() {
 target=$1
 if [ "$DRY_RUN" = "1" ]; then
  log "[DRY_RUN] write file $target"
  cat >/dev/null
  return 0
 fi
 tmp_file="${target}.tmp"
 cat >"$tmp_file"
 mv "$tmp_file" "$target"
}

extract_openclaw_token() {
 env_file=$1
 [ -f "$env_file" ] || return 1
 token=$(grep '^OPENCLAW_GATEWAY_TOKEN=' "$env_file" | tail -n 1 | cut -d '=' -f 2- || true)
 [ -n "$token" ] || return 1
 printf '%s' "$token"
}

[ "${1-}" = "--help" ] && {
 usage
 exit 0
}

require_env TRAEFIK_ACME_EMAIL
require_env OPENCLAW_DOMAIN
require_env OVH_ENDPOINT_API_KEY

CURRENT_USER=$(id -un)
HOME_DIR=${HOME:-"$(getent passwd "$CURRENT_USER" | cut -d : -f 6 2>/dev/null || printf '/home/%s' "$CURRENT_USER")"}
OPENCLAW_DIR=${OPENCLAW_DIR:-"$HOME_DIR/openclaw"}
OPENCLAW_CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-"$HOME_DIR/.openclaw"}
OPENCLAW_WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR:-"$OPENCLAW_CONFIG_DIR/workspace"}
TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME_DIR/docker/traefik"}
OPENCLAW_REPO=${OPENCLAW_REPO:-"https://github.com/openclaw/openclaw.git"}
OPENCLAW_IMAGE=${OPENCLAW_IMAGE:-"openclaw:local"}
OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-"lan"}
OVH_ENDPOINT_BASE_URL=${OVH_ENDPOINT_BASE_URL:-"https://oai.endpoints.kepler.ai.cloud.ovh.net/v1"}
OVH_ENDPOINT_MODEL=${OVH_ENDPOINT_MODEL:-"gpt-oss-120b"}
OPENCLAW_USER=${OPENCLAW_USER:-"$CURRENT_USER"}
SKIP_DOCKER_GROUP_SETUP=${SKIP_DOCKER_GROUP_SETUP:-"0"}
SKIP_OPENCLAW_WIZARD=${SKIP_OPENCLAW_WIZARD:-"0"}
OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-"https://$OPENCLAW_DOMAIN"}
DRY_RUN=${DRY_RUN:-"0"}

if [ "$DRY_RUN" = "1" ]; then
 log "DRY_RUN=1 enabled; no system or Docker changes will be applied"
else
 require_command docker
 require_command git
 docker compose version >/dev/null 2>&1 || fail "docker compose is required"

 log "Checking Docker access"
 if ! docker ps >/dev/null 2>&1; then
  if [ "$SKIP_DOCKER_GROUP_SETUP" = "1" ]; then
  fail "docker ps failed and SKIP_DOCKER_GROUP_SETUP=1"
  fi

  log "Adding $CURRENT_USER to the docker group"
  sudo usermod -aG docker "$CURRENT_USER"
  fail "Docker permissions updated. Reconnect or run 'newgrp docker', then rerun the script."
 fi
fi

log "Creating shared Docker network"
if [ "$DRY_RUN" = "1" ]; then
 log "[DRY_RUN] docker network inspect proxy"
 log "[DRY_RUN] docker network create proxy"
elif ! docker network inspect proxy >/dev/null 2>&1; then
 run_cmd docker network create proxy >/dev/null
fi

log "Writing Traefik configuration into $TRAEFIK_DIR"
run_cmd mkdir -p "$TRAEFIK_DIR/letsencrypt"
run_cmd chmod 700 "$TRAEFIK_DIR/letsencrypt"
run_cmd touch "$TRAEFIK_DIR/letsencrypt/acme.json"
run_cmd chmod 600 "$TRAEFIK_DIR/letsencrypt/acme.json"
write_file "$TRAEFIK_DIR/docker-compose.yml" <<EOF
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=${TRAEFIK_ACME_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - proxy

networks:
  proxy:
    external: true
EOF

if [ "$DRY_RUN" = "1" ]; then
 log "[DRY_RUN] (cd $TRAEFIK_DIR && docker compose up -d)"
else
 (
 cd "$TRAEFIK_DIR"
 log "Starting Traefik"
 run_cmd docker compose up -d
 )
fi

log "Preparing OpenClaw repository in $OPENCLAW_DIR"
if [ -d "$OPENCLAW_DIR/.git" ]; then
 (
 cd "$OPENCLAW_DIR"
 run_cmd git pull --ff-only
 )
else
 run_cmd git clone "$OPENCLAW_REPO" "$OPENCLAW_DIR"
fi

run_cmd mkdir -p "$OPENCLAW_WORKSPACE_DIR"
run_cmd sudo chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_DIR" "$OPENCLAW_CONFIG_DIR"

if [ ! -f "$OPENCLAW_DIR/.env" ] && [ "$SKIP_OPENCLAW_WIZARD" != "1" ]; then
 log "Running OpenClaw's docker setup wizard"
 if [ "$DRY_RUN" = "1" ]; then
  log "[DRY_RUN] (cd $OPENCLAW_DIR && ./docker-setup.sh)"
 else
  (
  cd "$OPENCLAW_DIR"
  ./docker-setup.sh
  )
 fi
fi

if [ "$DRY_RUN" != "1" ]; then
 [ -f "$OPENCLAW_DIR/.env" ] || fail "OpenClaw .env not found in $OPENCLAW_DIR. Run ./docker-setup.sh first."
fi

if [ -z "${OPENCLAW_TOKEN:-}" ]; then
 if [ "$DRY_RUN" = "1" ]; then
  OPENCLAW_TOKEN="dry-run-token"
 else
  OPENCLAW_TOKEN=$(extract_openclaw_token "$OPENCLAW_DIR/.env" || true)
 fi
fi
[ -n "${OPENCLAW_TOKEN:-}" ] || fail "Unable to determine OPENCLAW_TOKEN from $OPENCLAW_DIR/.env"

log "Writing OpenClaw docker-compose.yml"
write_file "$OPENCLAW_DIR/docker-compose.yml" <<EOF
services:
  openclaw-gateway:
    container_name: openclaw
    image: \${OPENCLAW_IMAGE:-${OPENCLAW_IMAGE}}
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: \${OPENCLAW_GATEWAY_TOKEN}
      CLAUDE_AI_SESSION_KEY: \${CLAUDE_AI_SESSION_KEY}
      CLAUDE_WEB_SESSION_KEY: \${CLAUDE_WEB_SESSION_KEY}
      CLAUDE_WEB_COOKIE: \${CLAUDE_WEB_COOKIE}
    volumes:
      - \${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - \${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
    init: true
    restart: unless-stopped
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "\${OPENCLAW_GATEWAY_BIND:-${OPENCLAW_GATEWAY_BIND}}",
        "--port",
        "18789"
      ]
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.openclaw.rule=Host(\`${OPENCLAW_DOMAIN}\`)"
      - "traefik.http.routers.openclaw.entrypoints=websecure"
      - "traefik.http.routers.openclaw.tls.certresolver=myresolver"
      - "traefik.http.services.openclaw.loadbalancer.server.port=18789"

networks:
  proxy:
    external: true
EOF

log "Ensuring OpenClaw .env contains local path overrides"
if [ "$DRY_RUN" = "1" ]; then
 log "[DRY_RUN] append OPENCLAW_CONFIG_DIR to $OPENCLAW_DIR/.env when missing"
 log "[DRY_RUN] append OPENCLAW_WORKSPACE_DIR to $OPENCLAW_DIR/.env when missing"
else
 if ! grep -q '^OPENCLAW_CONFIG_DIR=' "$OPENCLAW_DIR/.env"; then
  printf '\nOPENCLAW_CONFIG_DIR=%s\n' "$OPENCLAW_CONFIG_DIR" >>"$OPENCLAW_DIR/.env"
 fi
 if ! grep -q '^OPENCLAW_WORKSPACE_DIR=' "$OPENCLAW_DIR/.env"; then
  printf 'OPENCLAW_WORKSPACE_DIR=%s\n' "$OPENCLAW_WORKSPACE_DIR" >>"$OPENCLAW_DIR/.env"
 fi
fi

OPENCLAW_JSON="$OPENCLAW_CONFIG_DIR/openclaw.json"
if [ -f "$OPENCLAW_JSON" ]; then
 run_cmd cp "$OPENCLAW_JSON" "${OPENCLAW_JSON}.bak"
fi

log "Writing $OPENCLAW_JSON"
run_cmd mkdir -p "$OPENCLAW_CONFIG_DIR"
write_file "$OPENCLAW_JSON" <<EOF
{
 "messages": {
 "ackReactionScope": "group-mentions"
 },
 "commands": {
 "native": "auto",
 "nativeSkills": "auto"
 },
 "gateway": {
 "port": 18789,
 "mode": "local",
 "bind": "lan",
 "controlUi": {
 "allowedOrigins": [
 "${OPENCLAW_ALLOWED_ORIGIN}"
 ]
 },
 "auth": {
 "mode": "token",
 "token": "${OPENCLAW_TOKEN}"
 }
 },
 "models": {
 "mode": "merge",
 "providers": {
 "ovhcloud": {
 "baseUrl": "${OVH_ENDPOINT_BASE_URL}",
 "apiKey": "${OVH_ENDPOINT_API_KEY}",
 "api": "openai-completions",
 "models": [
 {
 "id": "${OVH_ENDPOINT_MODEL}",
 "name": "${OVH_ENDPOINT_MODEL}",
 "compat": {
 "supportsStore": false
 }
 }
 ]
 }
 }
 },
 "agents": {
 "defaults": {
 "model": {
 "primary": "ovhcloud/${OVH_ENDPOINT_MODEL}"
 },
 "models": {
 "ovhcloud/${OVH_ENDPOINT_MODEL}": {}
 }
 }
 }
}
EOF

if [ "$DRY_RUN" = "1" ]; then
 log "[DRY_RUN] (cd $OPENCLAW_DIR && docker compose down && docker compose up -d)"
else
 (
 cd "$OPENCLAW_DIR"
 log "Restarting OpenClaw"
 run_cmd docker compose down
 run_cmd docker compose up -d
 )
fi

log "OpenClaw deployment finished"
log "URL: https://${OPENCLAW_DOMAIN}"
log "Gateway token: ${OPENCLAW_TOKEN}"
log "Container logs: docker logs openclaw"
log "Pending device approvals: docker exec -it openclaw node dist/index.js devices list"
