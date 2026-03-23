#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

ask_access_mode() {
  printf 'Access mode [ssh-tunnel/public] [ssh-tunnel]: '
  read value
  value=${value:-ssh-tunnel}
  case "$value" in
    ssh-tunnel | public)
      OPENCLAW_ACCESS_MODE=$value
      ;;
    *)
      fail "Unsupported access mode: $value"
      ;;
  esac
}

# read a variable with optional default
ask_var() {
  var_name=$1
  prompt=$2
  default=$3

  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default"
    read value
    value=${value:-$default}
  else
    printf '%s (leave blank to skip): ' "$prompt"
    read value
  fi

  case "$var_name" in
    TRAEFIK_ACME_EMAIL) TRAEFIK_ACME_EMAIL=$value ;;
    OPENCLAW_DOMAIN) OPENCLAW_DOMAIN=$value ;;
    OVH_ENDPOINT_API_KEY) OVH_ENDPOINT_API_KEY=$value ;;
    OPENCLAW_TOKEN) OPENCLAW_TOKEN=$value ;;
    OPENCLAW_DIR) OPENCLAW_DIR=$value ;;
    OPENCLAW_CONFIG_DIR) OPENCLAW_CONFIG_DIR=$value ;;
    OPENCLAW_WORKSPACE_DIR) OPENCLAW_WORKSPACE_DIR=$value ;;
    TRAEFIK_DIR) TRAEFIK_DIR=$value ;;
    OPENCLAW_USER) OPENCLAW_USER=$value ;;
    DRY_RUN) DRY_RUN=$value ;;
    *)
      fail "Unsupported variable requested: $var_name"
      ;;
  esac
}

milestone() {
  ts=$(date +'%Y-%m-%d %H:%M:%S')
  printf '%s\n' "--- [$ts] $*"
}

if [ ! -f "$BUILD_SCRIPT" ]; then
  fail "build script not found at $BUILD_SCRIPT"
fi

milestone "Interactive OpenClaw setup started"

ask_access_mode
ask_var OVH_ENDPOINT_API_KEY "OVH endpoint API key" ""
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  ask_var TRAEFIK_ACME_EMAIL "Traefik email for ACME certs" "admin@example.com"
  ask_var OPENCLAW_DOMAIN "OpenClaw public domain (DNS must point to host)" "openclaw.example.com"
fi
ask_var OPENCLAW_TOKEN "OpenClaw gateway token (optional)" ""
ask_var OPENCLAW_DIR "Optional output directory for OpenClaw" "$HOME/openclaw"
ask_var OPENCLAW_CONFIG_DIR "Optional OpenClaw config directory" "$HOME/.openclaw"
ask_var OPENCLAW_WORKSPACE_DIR "Optional workspace directory" "$HOME/.openclaw/workspace"
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  ask_var TRAEFIK_DIR "Optional Traefik directory" "$HOME/docker/traefik"
fi
ask_var OPENCLAW_USER "System user that should own OpenClaw files (usually your SSH user)" "$(id -un)"
ask_var DRY_RUN "Dry-run mode (1=yes, 0=no)" "0"

milestone "Configuration complete - reviewing values"

cat << EOF2
OPENCLAW_ACCESS_MODE=$OPENCLAW_ACCESS_MODE
OVH_ENDPOINT_API_KEY=<redacted>
OPENCLAW_TOKEN=<redacted>
OPENCLAW_DIR=$OPENCLAW_DIR
OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
OPENCLAW_USER=$OPENCLAW_USER
DRY_RUN=$DRY_RUN
EOF2

if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  cat << EOF2
TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL
OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN
TRAEFIK_DIR=$TRAEFIK_DIR
EOF2
fi

printf 'Proceed with these settings? [y/N]: '
read answer
case "$(printf '%s' "$answer" | tr 'A-Z' 'a-z')" in
  y | yes) ;;
  *)
    fail 'User aborted.'
    ;;
esac

milestone "Exporting environment variables"

export OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY
export OPENCLAW_TOKEN
export OPENCLAW_DIR OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE_DIR OPENCLAW_USER
export DRY_RUN

if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  export TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN TRAEFIK_DIR
  export OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-https://$OPENCLAW_DOMAIN}
else
  export OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-http://127.0.0.1:18789}
fi

# optional variables for compatibility with build.sh
export OPENCLAW_REPO=${OPENCLAW_REPO:-https://github.com/openclaw/openclaw.git}
export OPENCLAW_IMAGE=${OPENCLAW_IMAGE:-openclaw:local}
export OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-lan}
export OVH_ENDPOINT_BASE_URL=${OVH_ENDPOINT_BASE_URL:-https://oai.endpoints.kepler.ai.cloud.ovh.net/v1}
export OVH_ENDPOINT_MODEL=${OVH_ENDPOINT_MODEL:-gpt-oss-120b}
export SKIP_DOCKER_GROUP_SETUP=${SKIP_DOCKER_GROUP_SETUP:-0}
export SKIP_OPENCLAW_WIZARD=${SKIP_OPENCLAW_WIZARD:-0}
export SKIP_OPENCLAW_IMAGE_BUILD=${SKIP_OPENCLAW_IMAGE_BUILD:-0}

milestone "Running core setup script on SSH-capable host"

sh "$BUILD_SCRIPT"

milestone "Interactive setup completed."

if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  cat << EOF2
Success: OpenClaw should now be deployed.
- Access: https://$OPENCLAW_DOMAIN
- Check container logs: docker logs openclaw
- Device approvals: docker exec -it openclaw node dist/index.js devices list
EOF2
else
  cat << 'EOF2'
Success: OpenClaw should now be deployed in private ssh-tunnel mode.
- Tunnel command: ssh -N -L 18789:127.0.0.1:18789 <user>@<host>
- Local access URL after tunnel: http://127.0.0.1:18789
- Check container logs: docker logs openclaw
- Device approvals: docker exec -it openclaw node dist/index.js devices list
EOF2
fi
