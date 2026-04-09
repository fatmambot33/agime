#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/lib/setup.sh
. "$SCRIPT_DIR/scripts/lib/setup.sh"

SETUP_MODE=${SETUP_MODE:-remote-sync}
SYNC_SCRIPT="$SCRIPT_DIR/sync.sh"
REMOTE_HOST=${REMOTE_HOST:-}
REMOTE_DIR=${REMOTE_DIR:-~/agime}
OPENCLAW_ACCESS_MODE=${OPENCLAW_ACCESS_MODE:-ssh-tunnel}
OVH_ENDPOINT_API_KEY=${OVH_ENDPOINT_API_KEY:-}
TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL:-}
OPENCLAW_DOMAIN=${OPENCLAW_DOMAIN:-}
OPENCLAW_TOKEN=${OPENCLAW_TOKEN:-}

run_local_install() {
  sh "$SCRIPT_DIR/scripts/entrypoints/docker.install.sh"
  sh "$SCRIPT_DIR/scripts/entrypoints/tailscale.install.sh"

  if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
    TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL \
    TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME/docker/traefik"} \
    sh "$SCRIPT_DIR/scripts/entrypoints/traefik.install.sh"
  fi

  sh "$SCRIPT_DIR/scripts/entrypoints/openclaw.install.sh"
}

case "$SETUP_MODE" in
  remote-sync)
    setup_validate
    TMP_SYNC_CONFIG=$(setup_build_temp_config)
    trap 'rm -f "$TMP_SYNC_CONFIG"' EXIT INT TERM

    export REMOTE_HOST REMOTE_DIR OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY
    export OPENCLAW_TOKEN TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN

    SYNC_CONFIG_FILE=/dev/null \
      SYNC_LOCAL_ENV_FILE="$TMP_SYNC_CONFIG" \
      SYNC_REMOTE_ENTRYPOINT=build.sh \
      sh "$SYNC_SCRIPT"
    ;;
  local-install)
    case "$OPENCLAW_ACCESS_MODE" in
      ssh-tunnel | public) ;;
      *)
        echo "Error: OPENCLAW_ACCESS_MODE must be ssh-tunnel or public for local-install mode." >&2
        exit 1
        ;;
    esac

    if [ "$OPENCLAW_ACCESS_MODE" = "public" ] && [ -z "$TRAEFIK_ACME_EMAIL" ]; then
      echo "Error: TRAEFIK_ACME_EMAIL is required in local-install mode when OPENCLAW_ACCESS_MODE=public." >&2
      exit 1
    fi

    run_local_install
    ;;
  *)
    echo "Error: SETUP_MODE must be remote-sync or local-install." >&2
    exit 1
    ;;
esac
