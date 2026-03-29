#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"

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

echo "=== OpenClaw Setup ==="
echo "This flow writes environment values and runs build.sh (template-based deployment)."
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
