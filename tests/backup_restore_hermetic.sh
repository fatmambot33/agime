#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_HOME="$TMP_DIR/home"
mkdir -p "$TEST_HOME/openclaw" "$TEST_HOME/.openclaw/workspace"

printf 'OPENCLAW_TOKEN=test-token\n' > "$TEST_HOME/openclaw/.env"
printf '# identity prompt\nYou are Test.\n' > "$TEST_HOME/.openclaw/workspace/IDENTITY.md"

ARCHIVE="$TMP_DIR/openclaw-backup.tgz"
RESTORE_ROOT="$TMP_DIR/restore"

(
  cd "$REPO_DIR"
  HOME="$TEST_HOME" \
    OPENCLAW_DIR="$TEST_HOME/openclaw" \
    OPENCLAW_CONFIG_DIR="$TEST_HOME/.openclaw" \
    BACKUP_OUTPUT="$ARCHIVE" \
    sh ./backup.sh
)

[ -f "$ARCHIVE" ]

rm -rf "$TEST_HOME/.openclaw" "$TEST_HOME/openclaw/.env"

(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$ARCHIVE" \
    RESTORE_ROOT="$RESTORE_ROOT" \
    sh ./restore.sh
)

RESTORED_IDENTITY="$RESTORE_ROOT$TEST_HOME/.openclaw/workspace/IDENTITY.md"
RESTORED_ENV="$RESTORE_ROOT$TEST_HOME/openclaw/.env"

[ -f "$RESTORED_IDENTITY" ]
[ -f "$RESTORED_ENV" ]

grep -Fq 'You are Test.' "$RESTORED_IDENTITY"
grep -Fq 'OPENCLAW_TOKEN=test-token' "$RESTORED_ENV"

echo "backup_restore_hermetic test passed"
