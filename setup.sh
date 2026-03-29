#!/bin/sh

set -eu

OFFICIAL_SETUP_URL=${OFFICIAL_SETUP_URL:-"https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/docker/setup.sh"}

echo "=== OpenClaw Setup ==="
echo "Running official setup script: $OFFICIAL_SETUP_URL"
echo ""

if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  printf "OpenClaw gateway token (leave blank to skip): "
  IFS= read -r OPENCLAW_GATEWAY_TOKEN
  export OPENCLAW_GATEWAY_TOKEN
fi

exec bash -c "$(curl -fsSL "$OFFICIAL_SETUP_URL")"
