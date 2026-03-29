#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
SYNC_SCRIPT="$SCRIPT_DIR/sync.sh"

[ -f "$SYNC_SCRIPT" ] || {
  echo "Missing sync script: $SYNC_SCRIPT" >&2
  exit 1
}

[ -n "${REMOTE_HOST:-}" ] || {
  echo "REMOTE_HOST is required (example: user@vps-host)." >&2
  exit 1
}

ask_default() {
  prompt=$1
  default=$2
  printf "%s [%s]: " "$prompt" "$default"
  IFS= read -r val
  printf '%s' "${val:-$default}"
}

ask_required() {
  prompt=$1
  while :; do
    printf "%s: " "$prompt"
    IFS= read -r val
    [ -n "$val" ] && {
      printf '%s' "$val"
      return 0
    }
    echo "This field is required."
  done
}

echo "=== OpenClaw OVH Remote Setup ==="
OPENCLAW_ACCESS_MODE=$(ask_default "Access mode (ssh-tunnel/public)" "ssh-tunnel")
case "$OPENCLAW_ACCESS_MODE" in
  ssh-tunnel | public) ;;
  *) echo "Unsupported access mode: $OPENCLAW_ACCESS_MODE" >&2; exit 1 ;;
esac

OVH_ENDPOINT_API_KEY=$(ask_required "OVH endpoint API key")
printf "OpenClaw gateway token (leave blank to skip): "
IFS= read -r OPENCLAW_TOKEN

TRAEFIK_ACME_EMAIL=""
OPENCLAW_DOMAIN=""
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  TRAEFIK_ACME_EMAIL=$(ask_required "Traefik ACME email")
  OPENCLAW_DOMAIN=$(ask_required "OpenClaw public domain")
fi

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

echo "Deploying remotely to $REMOTE_HOST:$REMOTE_DIR via sync.sh..."
SYNC_CONFIG_FILE="$TMP_SYNC_CONFIG" sh "$SYNC_SCRIPT"
echo "Remote setup complete."
