#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYNC_CONFIG_FILE=${SYNC_CONFIG_FILE:-"$SCRIPT_DIR/sync.conf"}

if [ -f "$SYNC_CONFIG_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$SYNC_CONFIG_FILE"
  set +a
fi

REMOTE_HOST=${REMOTE_HOST:-my-vps}
REMOTE_DIR=${REMOTE_DIR:-/tmp/agime}
OPENCLAW_ACTION=${OPENCLAW_ACTION:-}
SYNC_REMOTE_ENTRYPOINT=${SYNC_REMOTE_ENTRYPOINT:-build-interactive.sh}
SYNC_REMOTE_ENV_FILE=${SYNC_REMOTE_ENV_FILE:-}
SYNC_LOCAL_ENV_FILE=${SYNC_LOCAL_ENV_FILE:-"$SCRIPT_DIR/.sync-build.env"}
SYNC_MIRROR_ENV_FILE=${SYNC_MIRROR_ENV_FILE:-0}
SYNC_PRINT_CONFIG=${SYNC_PRINT_CONFIG:-0}
SYNC_ITEMS=${SYNC_ITEMS:-"build-interactive.sh build.sh backup.sh update.sh add_tool.sh restore.sh sync.sh scripts templates docs README.md"}
SSH_CONTROL_PERSIST_SECONDS=${SSH_CONTROL_PERSIST_SECONDS:-600}
SSH_CONTROL_PATH=${SSH_CONTROL_PATH:-"$HOME/.ssh/agime-sync-%r@%h:%p"}

SSH_BASE_ARGS="-o ControlMaster=auto -o ControlPersist=${SSH_CONTROL_PERSIST_SECONDS} -o ControlPath=$SSH_CONTROL_PATH"

ssh_exec() {
  # Keep sync orchestration local: only the wrapped command runs remotely.
  ssh $SSH_BASE_ARGS "$@"
}

scp_exec() {
  scp $SSH_BASE_ARGS "$@"
}

cleanup_ssh_master() {
  ssh_exec -O exit "$REMOTE_HOST" > /dev/null 2>&1 || true
}

print_effective_config() {
  printf '%s\n' "sync.sh effective config:"
  printf '  SYNC_CONFIG_FILE=%s\n' "$SYNC_CONFIG_FILE"
  printf '  REMOTE_HOST=%s\n' "$REMOTE_HOST"
  printf '  REMOTE_DIR=%s\n' "$REMOTE_DIR"
  printf '  SYNC_REMOTE_ENTRYPOINT=%s\n' "$SYNC_REMOTE_ENTRYPOINT"
  printf '  SYNC_REMOTE_ENV_FILE=%s\n' "${SYNC_REMOTE_ENV_FILE:-<none>}"
  printf '  SYNC_LOCAL_ENV_FILE=%s\n' "$SYNC_LOCAL_ENV_FILE"
  printf '  SYNC_MIRROR_ENV_FILE=%s\n' "$SYNC_MIRROR_ENV_FILE"
  printf '  OPENCLAW_ACTION=%s\n' "${OPENCLAW_ACTION:-<none>}"
  printf '  SSH_CONTROL_PERSIST_SECONDS=%s\n' "$SSH_CONTROL_PERSIST_SECONDS"
  printf '  SSH_CONTROL_PATH=%s\n' "$SSH_CONTROL_PATH"
  printf '  SYNC_ITEMS=%s\n' "$SYNC_ITEMS"
}

if [ "$SYNC_PRINT_CONFIG" = "1" ]; then
  print_effective_config
fi

trap 'cleanup_ssh_master' EXIT INT TERM

UPLOAD_ITEMS=$SYNC_ITEMS
if [ -f "$SYNC_CONFIG_FILE" ]; then
  case " $UPLOAD_ITEMS " in
    *" $SYNC_CONFIG_FILE "*) ;;
    *) UPLOAD_ITEMS="$UPLOAD_ITEMS $SYNC_CONFIG_FILE" ;;
  esac
fi

if [ -n "$SYNC_REMOTE_ENV_FILE" ] && [ -f "$SYNC_REMOTE_ENV_FILE" ]; then
  case " $UPLOAD_ITEMS " in
    *" $SYNC_REMOTE_ENV_FILE "*) ;;
    *) UPLOAD_ITEMS="$UPLOAD_ITEMS $SYNC_REMOTE_ENV_FILE" ;;
  esac
fi

ssh_exec "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
set -- $UPLOAD_ITEMS
scp_exec -r "$@" "$REMOTE_HOST:$REMOTE_DIR/"

if [ -n "$SYNC_REMOTE_ENV_FILE" ]; then
  REMOTE_ENV_SETUP=". './$SYNC_REMOTE_ENV_FILE' && "
else
  REMOTE_ENV_SETUP=""
fi

case "$SYNC_REMOTE_ENTRYPOINT" in
  build-interactive.sh)
    if [ -n "$OPENCLAW_ACTION" ]; then
      ssh_exec -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}OPENCLAW_ACTION='$OPENCLAW_ACTION' OPENCLAW_EXPORT_ENV_FILE='${SYNC_REMOTE_ENV_FILE:-}' ./build-interactive.sh"
    else
      ssh_exec -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}OPENCLAW_EXPORT_ENV_FILE='${SYNC_REMOTE_ENV_FILE:-}' ./build-interactive.sh"
    fi
    ;;
  build.sh)
    ssh_exec "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}./build.sh"
    ;;
  *)
    printf 'Error: unsupported SYNC_REMOTE_ENTRYPOINT: %s\n' "$SYNC_REMOTE_ENTRYPOINT" >&2
    exit 1
    ;;
esac

if [ "$SYNC_MIRROR_ENV_FILE" = "1" ] && [ -n "$SYNC_REMOTE_ENV_FILE" ]; then
  mkdir -p "$(dirname "$SYNC_LOCAL_ENV_FILE")"
  scp_exec "$REMOTE_HOST:$REMOTE_DIR/$SYNC_REMOTE_ENV_FILE" "$SYNC_LOCAL_ENV_FILE"
  chmod 600 "$SYNC_LOCAL_ENV_FILE"
fi
