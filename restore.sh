#!/usr/bin/env sh

set -eu

RESTORE_ARCHIVE=${RESTORE_ARCHIVE:-${1:-}}
RESTORE_ROOT=${RESTORE_ROOT:-/}
RESTORE_FORCE=${RESTORE_FORCE:-0}

if [ -z "$RESTORE_ARCHIVE" ]; then
  echo "Usage: RESTORE_ARCHIVE=/path/to/openclaw-backup.tar.gz [RESTORE_ROOT=/] [RESTORE_FORCE=1] sh restore.sh" >&2
  exit 1
fi

if [ ! -f "$RESTORE_ARCHIVE" ]; then
  echo "Archive not found: $RESTORE_ARCHIVE" >&2
  exit 1
fi

mkdir -p "$RESTORE_ROOT"
RESTORE_ROOT=$(CDPATH= cd -- "$RESTORE_ROOT" && pwd -P)

if [ "$RESTORE_ROOT" = "/" ] && [ "$RESTORE_FORCE" != "1" ]; then
  echo "Refusing to restore into / without RESTORE_FORCE=1" >&2
  exit 1
fi

echo "Restoring archive: $RESTORE_ARCHIVE"
echo "Destination root: $RESTORE_ROOT"
tar -xzf "$RESTORE_ARCHIVE" -C "$RESTORE_ROOT"

echo "Restore completed."
