#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SRC="$TMP_DIR/src"
mkdir -p "$SRC/.openclaw"
printf 'token=test\n' > "$SRC/.openclaw/state.txt"

ARCHIVE="$TMP_DIR/backup.tar.gz"
(
  cd "$REPO_DIR"
  OPENCLAW_CONFIG_DIR="$SRC/.openclaw" BACKUP_OUTPUT="$ARCHIVE" sh ./backup.sh
)

[ -f "$ARCHIVE" ]
RESTORE_DIR="$TMP_DIR/restore"
mkdir -p "$RESTORE_DIR"
(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$ARCHIVE" RESTORE_ROOT="$RESTORE_DIR" RESTORE_ALLOWED_PREFIXES="$SRC/.openclaw" sh ./restore.sh
)

[ -f "$RESTORE_DIR/$SRC/.openclaw/state.txt" ]

echo 'backup_restore_hermetic: ok'
