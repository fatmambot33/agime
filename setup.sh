#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
SYNC_SCRIPT="$SCRIPT_DIR/sync.sh"

[ -f "$SYNC_SCRIPT" ] || {
  echo "Missing sync script: $SYNC_SCRIPT" >&2
  exit 1
}

[ -n "${REMOTE_HOST:-}" ] || {
  echo "REMOTE_HOST is required (example: user@vps-host)." >&2
  exit 1
}

ask_default() {
  prompt=$1
  default=$2
  printf "%s [%s]: " "$prompt" "$default" >&2
  IFS= read -r val
  printf '%s' "${val:-$default}"
}

ask_required() {
  prompt=$1
  while :; do
    printf "%s: " "$prompt" >&2
    IFS= read -r val
    [ -n "$val" ] && {
      printf '%s' "$val"
      return 0
    }
    echo "This field is required." >&2
  done
}

canonicalize_home_path() {
  value=$1
  home_dir=${HOME:-}
  [ -n "$home_dir" ] || {
    printf '%s' "$value"
    return 0
  }

  case "$value" in
    "$home_dir")
      printf '~'
      ;;
    "$home_dir"/*)
      printf '~/%s' "${value#"$home_dir"/}"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

echo "=== OpenClaw OVH Remote Setup ==="
OPENCLAW_ACCESS_MODE=$(ask_default "Access mode (ssh-tunnel/public)" "ssh-tunnel")
case "$OPENCLAW_ACCESS_MODE" in
  ssh-tunnel | public) ;;
  *)
    echo "Unsupported access mode: $OPENCLAW_ACCESS_MODE" >&2
    exit 1
    ;;
esac

OVH_ENDPOINT_API_KEY=$(ask_required "OVH endpoint API key")
printf "OpenClaw gateway token (leave blank to skip): " >&2
IFS= read -r OPENCLAW_TOKEN

TRAEFIK_ACME_EMAIL=""
OPENCLAW_DOMAIN=""
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  TRAEFIK_ACME_EMAIL=$(ask_required "Traefik ACME email")
  OPENCLAW_DOMAIN=$(ask_required "OpenClaw public domain")
fi

REMOTE_DIR=${REMOTE_DIR:-"~/agime"}
REMOTE_DIR=$(canonicalize_home_path "$REMOTE_DIR")
TMP_SYNC_CONFIG=$(mktemp)
trap 'rm -f "$TMP_SYNC_CONFIG"' EXIT INT TERM

if [ -f "$SCRIPT_DIR/sync.conf.example" ]; then
  cp "$SCRIPT_DIR/sync.conf.example" "$TMP_SYNC_CONFIG"
else
  : > "$TMP_SYNC_CONFIG"
fi

append_kv() {
  key=$1
  value=$2
  if [ -f "$TMP_SYNC_CONFIG" ]; then
    tmp_clean=$(mktemp)
    awk -F= -v k="$key" '$1 != k { print }' "$TMP_SYNC_CONFIG" > "$tmp_clean"
    mv "$tmp_clean" "$TMP_SYNC_CONFIG"
  fi
  printf '%s=%s\n' "$key" "$value" >> "$TMP_SYNC_CONFIG"
}

append_kv "REMOTE_HOST" "$REMOTE_HOST"
append_kv "REMOTE_DIR" "$REMOTE_DIR"
append_kv "SYNC_REMOTE_ENTRYPOINT" "build.sh"
append_kv "OPENCLAW_ACCESS_MODE" "$OPENCLAW_ACCESS_MODE"
append_kv "OVH_ENDPOINT_API_KEY" "$OVH_ENDPOINT_API_KEY"
append_kv "OPENCLAW_TOKEN" "$OPENCLAW_TOKEN"
append_kv "TRAEFIK_ACME_EMAIL" "$TRAEFIK_ACME_EMAIL"
append_kv "OPENCLAW_DOMAIN" "$OPENCLAW_DOMAIN"

chmod 600 "$TMP_SYNC_CONFIG"

echo "Deploying remotely to $REMOTE_HOST:$REMOTE_DIR via sync.sh..."
SYNC_CONFIG_FILE="$TMP_SYNC_CONFIG" sh "$SYNC_SCRIPT"
echo "Remote setup complete."
