#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# sync.sh should fail fast for unsupported entrypoint.
cat > "$TMP_DIR/bad.conf" << EOF2
REMOTE_HOST=test-vps
REMOTE_DIR=~/agime
SYNC_REMOTE_ENTRYPOINT=configure.sh
OVH_ENDPOINT_API_KEY=test
EOF2

set +e
(
  cd "$REPO_DIR"
  SYNC_CONFIG_FILE="$TMP_DIR/bad.conf" sh ./sync.sh > "$TMP_DIR/sync.out" 2>&1
)
status=$?
set -e

[ "$status" -ne 0 ]
grep -q 'SYNC_REMOTE_ENTRYPOINT must be one of' "$TMP_DIR/sync.out"

# restore.sh should refuse root restore without force.
ARCHIVE="$TMP_DIR/archive.tar.gz"
mkdir -p "$TMP_DIR/src"
printf 'x\n' > "$TMP_DIR/src/value.txt"
(
  cd "$TMP_DIR/src"
  tar -czf "$ARCHIVE" .
)

set +e
(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$ARCHIVE" RESTORE_ROOT=/ sh ./restore.sh > "$TMP_DIR/restore.out" 2>&1
)
status=$?
set -e

[ "$status" -ne 0 ]
grep -q 'Refusing to restore into / without RESTORE_FORCE=1' "$TMP_DIR/restore.out"

echo 'failure_paths_hermetic: ok'
