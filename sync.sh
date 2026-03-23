#!/usr/bin/env sh

set -eu

REMOTE_HOST=${REMOTE_HOST:-my-vps}
REMOTE_DIR=${REMOTE_DIR:-/tmp/agime}

ssh "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
scp build-interactive.sh build.sh "$REMOTE_HOST:$REMOTE_DIR/"

ssh -t "$REMOTE_HOST" "cd '$REMOTE_DIR' && chmod +x ./*.sh && ./build-interactive.sh"
