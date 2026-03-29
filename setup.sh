#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
SECURITY_AUDIT_SCRIPT="$SCRIPT_DIR/scripts/run_security_audit.sh"
SECURITY_CRON_SCRIPT="$SCRIPT_DIR/scripts/install_security_audit_cron.sh"

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
echo "Secure defaults: ssh-tunnel mode + post-deploy security audit."
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

RUN_SECURITY_AUDIT=$(prompt_default "Run security audit after deploy? (1=yes,0=no)" "1")
INSTALL_SECURITY_CRON=$(prompt_default "Install daily security audit cron? (1=yes,0=no)" "1")

echo ""
echo "Deploying with build.sh..."

export OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY OPENCLAW_TOKEN
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  export TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN
fi

sh "$BUILD_SCRIPT"

if [ "$RUN_SECURITY_AUDIT" = "1" ] && [ -f "$SECURITY_AUDIT_SCRIPT" ]; then
  echo ""
  echo "Running security audit..."
  sh "$SECURITY_AUDIT_SCRIPT"
fi

if [ "$INSTALL_SECURITY_CRON" = "1" ] && [ -f "$SECURITY_CRON_SCRIPT" ]; then
  echo ""
  echo "Installing security audit cron..."
  sh "$SECURITY_CRON_SCRIPT"
fi

echo ""
echo "Setup complete."
