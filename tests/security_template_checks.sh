#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OPENCLAW_TEMPLATE="$SCRIPT_DIR/templates/openclaw.json.tmpl"
COMPOSE_TEMPLATE_PUBLIC="$SCRIPT_DIR/templates/openclaw-compose.public.yml.tmpl"
COMPOSE_TEMPLATE_SSH="$SCRIPT_DIR/templates/openclaw-compose.ssh-tunnel.yml.tmpl"

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

# Public compose should terminate TLS at Traefik and avoid host port publishing.
grep -Fq 'traefik.http.routers.openclaw.entrypoints=websecure' "$COMPOSE_TEMPLATE_PUBLIC"
grep -Fq 'traefik.http.routers.openclaw.tls.certresolver=myresolver' "$COMPOSE_TEMPLATE_PUBLIC"
if grep -Fq '\${' "$COMPOSE_TEMPLATE_PUBLIC"; then
  echo "Escaped Compose variable syntax found in public compose template" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*ports:' "$COMPOSE_TEMPLATE_PUBLIC"; then
  echo "Direct host port publishing is not allowed for public compose defaults" >&2
  exit 1
fi

# SSH tunnel compose must stay localhost-published and avoid Traefik labels.
grep -Fq '127.0.0.1:18789:18789' "$COMPOSE_TEMPLATE_SSH"
if grep -Fq 'traefik.http.routers' "$COMPOSE_TEMPLATE_SSH"; then
  echo "Traefik labels should not exist in ssh-tunnel compose template" >&2
  exit 1
fi

echo "Security template checks passed"
