#!/usr/bin/env sh

set -eu

REMOTE_HOST=${REMOTE_HOST:-my-vps}
REMOTE_DIR=${REMOTE_DIR:-/tmp/agime}
OPENCLAW_ACTION=${OPENCLAW_ACTION:-}
SYNC_ITEMS=${SYNC_ITEMS:-"build-interactive.sh build.sh backup.sh update.sh add_tool.sh restore.sh sync.sh scripts templates docs README.md"}

ssh "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
set -- $SYNC_ITEMS
scp -r "$@" "$REMOTE_HOST:$REMOTE_DIR/"

if [ -n "$OPENCLAW_ACTION" ]; then
  ssh -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && OPENCLAW_ACTION='$OPENCLAW_ACTION' ./build-interactive.sh"
else
  ssh -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && ./build-interactive.sh"
fi
