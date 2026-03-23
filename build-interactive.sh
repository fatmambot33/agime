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

  eval "$var_name=\"$value\""
}

milestone() {
  ts=$(date +'%Y-%m-%d %H:%M:%S')
  printf '%s\n' "--- [$ts] $*"
}

if [ ! -f "$BUILD_SCRIPT" ]; then
  fail "build script not found at $BUILD_SCRIPT"
fi

milestone "Interactive OpenClaw/Traefik setup started"

ask_var TRAEFIK_ACME_EMAIL "Traefik email for ACME certs" "admin@example.com"
ask_var OPENCLAW_DOMAIN "OpenClaw public domain (DNS must point to host)" "openclaw.example.com"
ask_var OVH_ENDPOINT_API_KEY "OVH endpoint API key" ""
ask_var OPENCLAW_TOKEN "OpenClaw gateway token (optional)" ""
ask_var OPENCLAW_DIR "Optional output directory for OpenClaw" "$HOME/openclaw"
ask_var OPENCLAW_CONFIG_DIR "Optional OpenClaw config directory" "$HOME/.openclaw"
ask_var OPENCLAW_WORKSPACE_DIR "Optional workspace directory" "$HOME/.openclaw/workspace"
ask_var TRAEFIK_DIR "Optional traefik directory" "$HOME/docker/traefik"
ask_var OPENCLAW_USER "System user for chown operations" "$(id -un)"
ask_var DRY_RUN "Dry-run mode (1=yes, 0=no)" "0"

milestone "Configuration complete - reviewing values"

cat <<EOF
TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL
OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN
OVH_ENDPOINT_API_KEY=$OVH_ENDPOINT_API_KEY
OPENCLAW_TOKEN=${OPENCLAW_TOKEN:-<not set>}
OPENCLAW_DIR=$OPENCLAW_DIR
OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
TRAEFIK_DIR=$TRAEFIK_DIR
OPENCLAW_USER=$OPENCLAW_USER
DRY_RUN=$DRY_RUN
EOF

printf 'Proceed with these settings? [y/N]: '
read answer
case "$(printf '%s' "$answer" | tr 'A-Z' 'a-z')" in
  y|yes)
    ;;
  *)
    fail 'User aborted.'
    ;;
esac

milestone "Exporting environment variables"

export TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN OVH_ENDPOINT_API_KEY
export OPENCLAW_TOKEN
export OPENCLAW_DIR OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE_DIR TRAEFIK_DIR OPENCLAW_USER
export DRY_RUN

# optional variables for compatibility with build.sh
export OPENCLAW_REPO=${OPENCLAW_REPO:-https://github.com/openclaw/openclaw.git}
export OPENCLAW_IMAGE=${OPENCLAW_IMAGE:-openclaw:local}
export OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-lan}
export OVH_ENDPOINT_BASE_URL=${OVH_ENDPOINT_BASE_URL:-https://oai.endpoints.kepler.ai.cloud.ovh.net/v1}
export OVH_ENDPOINT_MODEL=${OVH_ENDPOINT_MODEL:-gpt-oss-120b}
export SKIP_DOCKER_GROUP_SETUP=${SKIP_DOCKER_GROUP_SETUP:-0}
export SKIP_OPENCLAW_WIZARD=${SKIP_OPENCLAW_WIZARD:-0}
export OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-https://$OPENCLAW_DOMAIN}

milestone "Running core setup script on SSH-capable host"

sh "$BUILD_SCRIPT"

milestone "Interactive setup completed."

cat <<EOF
Success: OpenClaw should now be deployed.
- Access: https://$OPENCLAW_DOMAIN
- Check container logs: docker logs openclaw
- Device approvals: docker exec -it openclaw node dist/index.js devices list
EOF
