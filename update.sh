#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/lib/update.sh
. "$SCRIPT_DIR/scripts/lib/update.sh"

BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

GIT_PULL=${GIT_PULL:-auto}
RUN_BACKUP=${RUN_BACKUP:-1}
RUN_BUILD=${RUN_BUILD:-1}
BACKUP_OUTPUT=${BACKUP_OUTPUT:-"$SCRIPT_DIR/openclaw-update-backup-$(date +%Y%m%d-%H%M%S).tar.gz"}

update_maybe_pull
update_maybe_backup
update_maybe_build

echo "Update workflow completed."
