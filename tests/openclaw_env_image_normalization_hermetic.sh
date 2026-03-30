#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SCRIPT_DIR="$REPO_DIR"
# shellcheck source=scripts/build_lib.sh
. "$REPO_DIR/scripts/build_lib.sh"
# shellcheck source=scripts/build_steps.sh
. "$REPO_DIR/scripts/build_steps.sh"

OPENCLAW_DIR="$TMP_DIR/openclaw"
OPENCLAW_CONFIG_DIR="$TMP_DIR/config"
OPENCLAW_WORKSPACE_DIR="$TMP_DIR/workspace"
OPENCLAW_IMAGE='ghcr.io/openclaw/openclaw:latest'
DRY_RUN=0

mkdir -p "$OPENCLAW_DIR"
cat > "$OPENCLAW_DIR/.env" << 'EOF2'
OPENCLAW_GATEWAY_TOKEN=abc
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_CONFIG_DIR=/old/config
OPENCLAW_IMAGE=openclaw:local-2
EOF2

ensure_openclaw_env_overrides

grep -q '^OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest$' "$OPENCLAW_DIR/.env"
[ "$(grep -c '^OPENCLAW_IMAGE=' "$OPENCLAW_DIR/.env")" -eq 1 ]
grep -q '^OPENCLAW_CONFIG_DIR=/old/config$' "$OPENCLAW_DIR/.env"
grep -q '^OPENCLAW_WORKSPACE_DIR=' "$OPENCLAW_DIR/.env"

echo 'openclaw_env_image_normalization_hermetic: ok'
