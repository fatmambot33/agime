#!/usr/bin/env sh

set -eu

REMOTE_HOST=${REMOTE_HOST:-my-vps}
REMOTE_DIR=${REMOTE_DIR:-/tmp/agime}
OPENCLAW_ACTION=${OPENCLAW_ACTION:-}
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
  ssh_exec -O exit "$REMOTE_HOST" >/dev/null 2>&1 || true
}

trap 'cleanup_ssh_master' EXIT INT TERM

ssh_exec "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
set -- $SYNC_ITEMS
scp_exec -r "$@" "$REMOTE_HOST:$REMOTE_DIR/"

if [ -n "$OPENCLAW_ACTION" ]; then
  ssh_exec -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && OPENCLAW_ACTION='$OPENCLAW_ACTION' ./build-interactive.sh"
else
  ssh_exec -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && ./build-interactive.sh"
fi
