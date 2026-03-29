#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
OFFICIAL_SETUP_URL=${OFFICIAL_SETUP_URL:-"https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/docker/setup.sh"}

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

echo "=== OpenClaw Setup (official) ==="
echo "Source: $OFFICIAL_SETUP_URL"
echo ""

OPENCLAW_GATEWAY_TOKEN=$(prompt_optional "OpenClaw gateway token")
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
  export OPENCLAW_GATEWAY_TOKEN
fi

printf "Save OVH-ready values to .sync-build.env for later toolkit runs? [Y/n]: "
IFS= read -r save_ovh
save_ovh=${save_ovh:-Y}

case "$save_ovh" in
  Y | y | yes | YES)
    printf "Access mode (ssh-tunnel/public) [ssh-tunnel]: "
    IFS= read -r OPENCLAW_ACCESS_MODE
    OPENCLAW_ACCESS_MODE=${OPENCLAW_ACCESS_MODE:-ssh-tunnel}
    OVH_ENDPOINT_API_KEY=$(prompt_optional "OVH endpoint API key")
    TRAEFIK_ACME_EMAIL=""
    OPENCLAW_DOMAIN=""
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
    echo "Saved OVH-ready values to $SCRIPT_DIR/.sync-build.env"
    ;;
esac

echo ""
echo "Running official setup script..."
exec bash -c "$(curl -fsSL "$OFFICIAL_SETUP_URL")"
