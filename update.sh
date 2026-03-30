#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

GIT_PULL=${GIT_PULL:-auto}
RUN_BACKUP=${RUN_BACKUP:-1}
RUN_BUILD=${RUN_BUILD:-1}
BACKUP_OUTPUT=${BACKUP_OUTPUT:-"$SCRIPT_DIR/openclaw-update-backup-$(date +%Y%m%d-%H%M%S).tar.gz"}

fail() {
  printf 'update.sh error: %s\n' "$*" >&2
  exit 1
}

case "$GIT_PULL" in
  auto)
    if [ -d "$SCRIPT_DIR/.git" ]; then
      git -C "$SCRIPT_DIR" pull --ff-only
    fi
    ;;
  1)
    [ -d "$SCRIPT_DIR/.git" ] || fail "cannot use GIT_PULL=1 outside a git checkout"
    git -C "$SCRIPT_DIR" pull --ff-only
    ;;
  0) ;;
  *) fail "GIT_PULL must be auto, 1, or 0" ;;
esac

case "$RUN_BACKUP" in
  1)
    env BACKUP_OUTPUT="$BACKUP_OUTPUT" sh "$BACKUP_SCRIPT"
    ;;
  0) ;;
  *) fail "RUN_BACKUP must be 1 or 0" ;;
esac

case "$RUN_BUILD" in
  1) sh "$BUILD_SCRIPT" ;;
  0) ;;
  *) fail "RUN_BUILD must be 1 or 0" ;;
esac

echo "Update workflow completed."
