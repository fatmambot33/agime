#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
SYNC_SCRIPT="$SCRIPT_DIR/sync.sh"

prompt_default() {
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
  echo "Missing build script: $BUILD_SCRIPT" >&2
  exit 1
}

echo "=== OpenClaw OVH Setup ==="
echo "Secure default: ssh-tunnel mode."
echo ""

OPENCLAW_ACCESS_MODE=$(prompt_default "Access mode (ssh-tunnel/public)" "ssh-tunnel")
case "$OPENCLAW_ACCESS_MODE" in
  ssh-tunnel | public) ;;
  *)
    echo "Unsupported access mode: $OPENCLAW_ACCESS_MODE" >&2
    exit 1
    ;;
esac

OVH_ENDPOINT_API_KEY=$(prompt_required "OVH endpoint API key")
OPENCLAW_TOKEN=$(prompt_optional "OpenClaw gateway token")

TRAEFIK_ACME_EMAIL=""
OPENCLAW_DOMAIN=""
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  TRAEFIK_ACME_EMAIL=$(prompt_required "Traefik ACME email")
  OPENCLAW_DOMAIN=$(prompt_required "OpenClaw public domain")
fi

echo ""
echo "Deploying with build.sh..."

export OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY OPENCLAW_TOKEN
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  export TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN
fi

if [ -n "${REMOTE_HOST:-}" ]; then
  [ -f "$SYNC_SCRIPT" ] || {
    echo "Missing sync script: $SYNC_SCRIPT" >&2
    exit 1
  }

  REMOTE_DIR=${REMOTE_DIR:-"~/agime"}
  TMP_SYNC_CONFIG=$(mktemp)
  trap 'rm -f "$TMP_SYNC_CONFIG"' EXIT INT TERM

  cat > "$TMP_SYNC_CONFIG" <<EOF2
REMOTE_HOST=$REMOTE_HOST
REMOTE_DIR=$REMOTE_DIR
SYNC_REMOTE_ENTRYPOINT=build.sh
OPENCLAW_ACCESS_MODE=$OPENCLAW_ACCESS_MODE
OVH_ENDPOINT_API_KEY=$OVH_ENDPOINT_API_KEY
OPENCLAW_TOKEN=$OPENCLAW_TOKEN
TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL
OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN
EOF2

  chmod 600 "$TMP_SYNC_CONFIG"
  echo ""
  echo "Deploying remotely to $REMOTE_HOST:$REMOTE_DIR via sync.sh..."
  SYNC_CONFIG_FILE="$TMP_SYNC_CONFIG" sh "$SYNC_SCRIPT"
  echo ""
  echo "Remote setup complete."
  exit 0
fi

sh "$BUILD_SCRIPT"
echo ""
echo "Setup complete."
