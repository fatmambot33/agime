#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYNC_CONFIG_FILE=${SYNC_CONFIG_FILE:-"$SCRIPT_DIR/sync.conf"}

REMOTE_HOST=${REMOTE_HOST:-}
REMOTE_DIR=${REMOTE_DIR:-~/agime}
SYNC_REMOTE_ENTRYPOINT=${SYNC_REMOTE_ENTRYPOINT:-build.sh}
SYNC_REMOTE_ENV_FILE=${SYNC_REMOTE_ENV_FILE:-sync.conf}
SYNC_LOCAL_ENV_FILE=${SYNC_LOCAL_ENV_FILE:-$SYNC_CONFIG_FILE}
SYNC_PRINT_CONFIG=${SYNC_PRINT_CONFIG:-0}
SSH_CONTROL_PERSIST_SECONDS=${SSH_CONTROL_PERSIST_SECONDS:-600}
SSH_CONTROL_PATH=${SSH_CONTROL_PATH:-"$HOME/.ssh/agime-sync-%r@%h:%p"}
SYNC_ITEMS=${SYNC_ITEMS:-"build.sh sync.sh setup.sh backup.sh restore.sh update.sh scripts templates docs README.md Makefile"}

SSH_BASE_ARGS="-o ControlMaster=auto -o ControlPersist=${SSH_CONTROL_PERSIST_SECONDS} -o ControlPath=$SSH_CONTROL_PATH"

fail() {
  printf 'sync.sh error: %s\n' "$*" >&2
  exit 1
}

load_config() {
  [ -f "$SYNC_CONFIG_FILE" ] || return 0
  set -a
  # shellcheck disable=SC1090
  . "$SYNC_CONFIG_FILE"
  set +a
}

remote_home_path() {
  case "$1" in
    '~') printf '$HOME' ;;
    '~/'*) printf '$HOME/%s' "${1#\~/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

validate() {
  [ -n "$REMOTE_HOST" ] || fail "REMOTE_HOST is required (example: ubuntu@203.0.113.10)."

  case "$SYNC_REMOTE_ENTRYPOINT" in
    build.sh | update.sh | backup.sh | restore.sh) ;;
    *) fail "SYNC_REMOTE_ENTRYPOINT must be one of: build.sh, update.sh, backup.sh, restore.sh" ;;
  esac

  if [ "$SYNC_REMOTE_ENTRYPOINT" = "build.sh" ]; then
    [ -n "${OVH_ENDPOINT_API_KEY:-}" ] || {
      if [ -f "$SYNC_LOCAL_ENV_FILE" ] && grep -q '^[[:space:]]*OVH_ENDPOINT_API_KEY=' "$SYNC_LOCAL_ENV_FILE"; then
        :
      else
        fail "OVH_ENDPOINT_API_KEY is required for build.sh remote runs."
      fi
    }
  fi
}

print_effective_config() {
  printf 'sync.sh effective config:\n'
  printf '  REMOTE_HOST=%s\n' "$REMOTE_HOST"
  printf '  REMOTE_DIR=%s\n' "$REMOTE_DIR"
  printf '  SYNC_REMOTE_ENTRYPOINT=%s\n' "$SYNC_REMOTE_ENTRYPOINT"
  printf '  SYNC_REMOTE_ENV_FILE=%s\n' "$SYNC_REMOTE_ENV_FILE"
  printf '  SYNC_LOCAL_ENV_FILE=%s\n' "$SYNC_LOCAL_ENV_FILE"
  printf '  SYNC_ITEMS=%s\n' "$SYNC_ITEMS"
}

load_config
validate

[ "$SYNC_PRINT_CONFIG" = "1" ] && print_effective_config

REMOTE_DIR_SSH=$(remote_home_path "$REMOTE_DIR")

ssh $SSH_BASE_ARGS "$REMOTE_HOST" "mkdir -p \"$REMOTE_DIR_SSH\""
# shellcheck disable=SC2086
scp $SSH_BASE_ARGS -r $SYNC_ITEMS "$REMOTE_HOST:$REMOTE_DIR/"

if [ -n "$SYNC_REMOTE_ENV_FILE" ] && [ -f "$SYNC_LOCAL_ENV_FILE" ]; then
  scp $SSH_BASE_ARGS "$SYNC_LOCAL_ENV_FILE" "$REMOTE_HOST:$REMOTE_DIR/$SYNC_REMOTE_ENV_FILE"
  REMOTE_ENV_SETUP="set -a && . './$SYNC_REMOTE_ENV_FILE' && set +a && "
else
  REMOTE_ENV_SETUP=""
fi

ssh $SSH_BASE_ARGS "$REMOTE_HOST" "cd \"$REMOTE_DIR_SSH\" && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}./$SYNC_REMOTE_ENTRYPOINT"
ssh $SSH_BASE_ARGS -O exit "$REMOTE_HOST" > /dev/null 2>&1 || true
