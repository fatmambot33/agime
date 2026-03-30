#!/usr/bin/env sh
# shellcheck shell=sh

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/scripts/lib/common.sh"

setup_validate() {
  [ -x "$SYNC_SCRIPT" ] || fail "sync.sh not found at $SYNC_SCRIPT"
  require_nonempty "REMOTE_HOST" "$REMOTE_HOST"
  require_nonempty "OVH_ENDPOINT_API_KEY" "$OVH_ENDPOINT_API_KEY"

  case "$OPENCLAW_ACCESS_MODE" in
    ssh-tunnel | public) ;;
    *) fail "OPENCLAW_ACCESS_MODE must be ssh-tunnel or public" ;;
  esac

  if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
    require_nonempty "TRAEFIK_ACME_EMAIL" "$TRAEFIK_ACME_EMAIL"
    require_nonempty "OPENCLAW_DOMAIN" "$OPENCLAW_DOMAIN"
  fi
}

setup_build_temp_config() {
  tmp_sync_config=$(mktemp)
  cat > "$tmp_sync_config" << EOF2
REMOTE_HOST=$REMOTE_HOST
REMOTE_DIR=$REMOTE_DIR
SYNC_REMOTE_ENTRYPOINT=build.sh
OPENCLAW_ACCESS_MODE=$OPENCLAW_ACCESS_MODE
OVH_ENDPOINT_API_KEY=$OVH_ENDPOINT_API_KEY
OPENCLAW_TOKEN=$OPENCLAW_TOKEN
TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL
OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN
EOF2
  chmod 600 "$tmp_sync_config"
  printf '%s' "$tmp_sync_config"
}
