#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
OFFICIAL_SETUP_URL=${OFFICIAL_SETUP_URL:-"https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/docker/setup.sh"}
SETUP_IMPL=${SETUP_IMPL:-templates}
if [ "${1:-}" = "--official" ]; then
  SETUP_IMPL=official
  shift
fi

prompt_with_default() {
  prompt=$1
  default=$2
  printf "%s [%s]: " "$prompt" "$default"
  IFS= read -r value
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$default"
  fi
}

prompt_optional() {
  prompt=$1
  printf "%s (leave blank to skip): " "$prompt"
  IFS= read -r value
  printf '%s' "$value"
}

prompt_required() {
  prompt=$1
  while :; do
    printf "%s: " "$prompt"
    IFS= read -r value
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
    echo "This field is required."
  done
}

[ -f "$BUILD_SCRIPT" ] || {
  echo "build.sh not found at $BUILD_SCRIPT" >&2
  exit 1
}

if [ "$SETUP_IMPL" = "official" ]; then
  echo "=== OpenClaw Setup (official script) ==="
  echo "Source: $OFFICIAL_SETUP_URL"
  echo ""
  OPENCLAW_GATEWAY_TOKEN=$(prompt_optional "OpenClaw gateway token for official setup")
  if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
    export OPENCLAW_GATEWAY_TOKEN
  fi

  echo ""
  echo "Optional OVH values (saved for later build.sh use; official script does not consume them directly)."
  OPENCLAW_ACCESS_MODE=$(prompt_with_default "Access mode (ssh-tunnel/public)" "ssh-tunnel")
  OVH_ENDPOINT_API_KEY=$(prompt_optional "OVH endpoint API key")
  TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL:-}
  OPENCLAW_DOMAIN=${OPENCLAW_DOMAIN:-}
  if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
    TRAEFIK_ACME_EMAIL=$(prompt_required "Traefik ACME email")
    OPENCLAW_DOMAIN=$(prompt_required "OpenClaw public domain")
  fi

  cat > "$SCRIPT_DIR/.sync-build.env" <<EOF2
OPENCLAW_ACCESS_MODE=$OPENCLAW_ACCESS_MODE
OVH_ENDPOINT_API_KEY=$OVH_ENDPOINT_API_KEY
TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL
OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN
EOF2
  chmod 600 "$SCRIPT_DIR/.sync-build.env"
  echo "Wrote OVH-ready values to $SCRIPT_DIR/.sync-build.env"
  echo "Running official setup script..."
  exec bash -c "$(curl -fsSL "$OFFICIAL_SETUP_URL")"
fi

echo "=== OpenClaw Setup (template-based) ==="
echo "This flow writes environment values and runs build.sh."
echo ""

OPENCLAW_ACCESS_MODE=$(prompt_with_default "Access mode (ssh-tunnel/public)" "ssh-tunnel")
case "$OPENCLAW_ACCESS_MODE" in
  ssh-tunnel | public) ;;
  *)
    echo "Unsupported access mode: $OPENCLAW_ACCESS_MODE" >&2
    exit 1
    ;;
esac

OVH_ENDPOINT_API_KEY=$(prompt_required "OVH endpoint API key")
OPENCLAW_TOKEN=$(prompt_optional "OpenClaw gateway token")

TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL:-}
OPENCLAW_DOMAIN=${OPENCLAW_DOMAIN:-}
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  TRAEFIK_ACME_EMAIL=$(prompt_required "Traefik ACME email")
  OPENCLAW_DOMAIN=$(prompt_required "OpenClaw public domain")
fi

echo ""
echo "Running build.sh..."

export OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY OPENCLAW_TOKEN
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  export TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN
fi

exec sh "$BUILD_SCRIPT"
