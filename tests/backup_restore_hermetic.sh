#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_HOME="$TMP_DIR/home"
mkdir -p "$TEST_HOME/openclaw" "$TEST_HOME/.openclaw/workspace"
mkdir -p "$TEST_HOME/custom"

printf 'OPENCLAW_TOKEN=test-token\n' > "$TEST_HOME/openclaw/.env"
printf 'version: \"3\"\nservices:\n  openclaw:\n    image: openclaw:local\n' > "$TEST_HOME/openclaw/docker-compose.yml"
printf '# identity prompt\nYou are Test.\n' > "$TEST_HOME/.openclaw/workspace/IDENTITY.md"
printf 'custom keep me\n' > "$TEST_HOME/custom/extra.txt"

ARCHIVE="$TMP_DIR/openclaw-backup.tgz"
RESTORE_ROOT="$TMP_DIR/restore"

(
  cd "$REPO_DIR"
  HOME="$TEST_HOME" \
    OPENCLAW_DIR="$TEST_HOME/openclaw" \
    OPENCLAW_CONFIG_DIR="$TEST_HOME/.openclaw" \
    EXTRA_BACKUP_PATHS="$TEST_HOME/custom/extra.txt" \
    BACKUP_OUTPUT="$ARCHIVE" \
    sh ./backup.sh
)

[ -f "$ARCHIVE" ]

rm -rf "$TEST_HOME/.openclaw" "$TEST_HOME/openclaw/.env" "$TEST_HOME/openclaw/docker-compose.yml" "$TEST_HOME/custom/extra.txt"

(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$ARCHIVE" \
    RESTORE_ROOT="$RESTORE_ROOT" \
    sh ./restore.sh
)

RESTORED_IDENTITY="$RESTORE_ROOT$TEST_HOME/.openclaw/workspace/IDENTITY.md"
RESTORED_ENV="$RESTORE_ROOT$TEST_HOME/openclaw/.env"
RESTORED_COMPOSE="$RESTORE_ROOT$TEST_HOME/openclaw/docker-compose.yml"
RESTORED_EXTRA="$RESTORE_ROOT$TEST_HOME/custom/extra.txt"

[ -f "$RESTORED_IDENTITY" ]
[ -f "$RESTORED_ENV" ]
[ -f "$RESTORED_COMPOSE" ]
[ -f "$RESTORED_EXTRA" ]

grep -Fq 'You are Test.' "$RESTORED_IDENTITY"
grep -Fq 'OPENCLAW_TOKEN=test-token' "$RESTORED_ENV"
grep -Fq 'openclaw:local' "$RESTORED_COMPOSE"
grep -Fq 'custom keep me' "$RESTORED_EXTRA"

echo "backup_restore_hermetic test passed"
