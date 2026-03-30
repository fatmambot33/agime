#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/lib/sync.sh
. "$SCRIPT_DIR/scripts/lib/sync.sh"

SYNC_CONFIG_FILE=${SYNC_CONFIG_FILE:-"$SCRIPT_DIR/sync.conf"}
REMOTE_HOST=${REMOTE_HOST:-}
REMOTE_DIR=${REMOTE_DIR:-~/agime}
SYNC_REMOTE_ENTRYPOINT=${SYNC_REMOTE_ENTRYPOINT:-build.sh}
SYNC_REMOTE_ENV_FILE=${SYNC_REMOTE_ENV_FILE:-sync.conf}
SYNC_LOCAL_ENV_FILE=${SYNC_LOCAL_ENV_FILE:-$SYNC_CONFIG_FILE}
SYNC_PRINT_CONFIG=${SYNC_PRINT_CONFIG:-0}
SSH_CONTROL_PERSIST_SECONDS=${SSH_CONTROL_PERSIST_SECONDS:-600}
SSH_CONTROL_PATH=${SSH_CONTROL_PATH:-"$HOME/.ssh/agime-sync-%r@%h:%p"}
SYNC_ITEMS_FILE=${SYNC_ITEMS_FILE:-}
SSH_BASE_ARGS="-o ControlMaster=auto -o ControlPersist=${SSH_CONTROL_PERSIST_SECONDS} -o ControlPath=$SSH_CONTROL_PATH"

sync_load_config
sync_set_default_items_if_unset
sync_validate_requirements

[ "$SYNC_PRINT_CONFIG" = "1" ] && sync_print_effective_config

sync_upload_and_run
