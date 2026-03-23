#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OPENCLAW_TEMPLATE="$SCRIPT_DIR/templates/openclaw.json.tmpl"
COMPOSE_TEMPLATE="$SCRIPT_DIR/templates/openclaw-compose.yml.tmpl"

# Gateway auth should be token-based and sourced from runtime config.
grep -Eq '"auth"[[:space:]]*:[[:space:]]*\{' "$OPENCLAW_TEMPLATE"
grep -Eq '"mode"[[:space:]]*:[[:space:]]*"token"' "$OPENCLAW_TEMPLATE"
grep -Eq '"token"[[:space:]]*:[[:space:]]*"__OPENCLAW_TOKEN__"' "$OPENCLAW_TEMPLATE"

# Control UI origin must be explicit and templated, not wildcard.
grep -Eq '"allowedOrigins"[[:space:]]*:[[:space:]]*\[' "$OPENCLAW_TEMPLATE"
grep -Eq '"__OPENCLAW_ALLOWED_ORIGIN__"' "$OPENCLAW_TEMPLATE"
if grep -Eq '"allowedOrigins"[[:space:]]*:[[:space:]]*\[[^]]*"\*"' "$OPENCLAW_TEMPLATE"; then
  echo "Wildcard allowedOrigins is not permitted in template defaults" >&2
  exit 1
fi

# Avoid insecure auth defaults in the gateway template.
if grep -Eq '"mode"[[:space:]]*:[[:space:]]*"none"' "$OPENCLAW_TEMPLATE"; then
  echo "Insecure gateway auth mode 'none' found in template" >&2
  exit 1
fi

# Compose should terminate TLS at Traefik and avoid host port publishing.
grep -Fq 'traefik.http.routers.openclaw.entrypoints=websecure' "$COMPOSE_TEMPLATE"
grep -Fq 'traefik.http.routers.openclaw.tls.certresolver=myresolver' "$COMPOSE_TEMPLATE"
if grep -Fq '\${' "$COMPOSE_TEMPLATE"; then
  echo "Escaped Compose variable syntax found in openclaw-compose template" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*ports:' "$COMPOSE_TEMPLATE"; then
  echo "Direct host port publishing is not allowed for openclaw-compose defaults" >&2
  exit 1
fi

echo "Security template checks passed"
