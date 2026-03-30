#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SCRIPT_DIR="$REPO_DIR"
# shellcheck source=scripts/build_lib.sh
. "$REPO_DIR/scripts/build_lib.sh"

TRAEFIK_ACME_EMAIL='ops@example.com'
OPENCLAW_IMAGE='ghcr.io/example/openclaw:test'
OPENCLAW_GATEWAY_BIND='lan'
OPENCLAW_DOMAIN='openclaw.example.com'
OPENCLAW_ALLOWED_ORIGIN='https://openclaw.example.com'
OPENCLAW_TOKEN='token/with&chars'
OVH_ENDPOINT_BASE_URL='https://oai.example/v1'
OVH_ENDPOINT_API_KEY='abc123'
OVH_ENDPOINT_MODEL='gpt-oss-120b'
DRY_RUN=0

cat > "$TMP_DIR/template.tmpl" << 'EOF2'
EMAIL=__TRAEFIK_ACME_EMAIL__
IMAGE=__OPENCLAW_IMAGE__
TOKEN=__OPENCLAW_TOKEN__
ENDPOINT=__OVH_ENDPOINT_BASE_URL__
EOF2

render_template "$TMP_DIR/rendered.conf" "$TMP_DIR/template.tmpl"

grep -q 'EMAIL=ops@example.com' "$TMP_DIR/rendered.conf"
grep -q 'IMAGE=ghcr.io/example/openclaw:test' "$TMP_DIR/rendered.conf"
grep -q 'TOKEN=token/with&chars' "$TMP_DIR/rendered.conf"
grep -q 'ENDPOINT=https://oai.example/v1' "$TMP_DIR/rendered.conf"

echo 'template_render_hermetic: ok'
