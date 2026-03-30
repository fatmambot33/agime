#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SAFE_SRC="$TMP_DIR/safe-src"
mkdir -p "$SAFE_SRC/root/.openclaw"
printf 'ok\n' > "$SAFE_SRC/root/.openclaw/state.txt"
SAFE_ARCHIVE="$TMP_DIR/safe.tar.gz"
(
  cd "$SAFE_SRC"
  tar -czf "$SAFE_ARCHIVE" .
)

# Dry-run preflight should pass without extracting.
(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$SAFE_ARCHIVE" RESTORE_ROOT="$TMP_DIR/restore" RESTORE_DRY_RUN=1 RESTORE_ALLOWED_PREFIXES='/root/.openclaw' sh ./restore.sh > "$TMP_DIR/dry-run.out"
)
grep -q 'preflight succeeded and no files were extracted' "$TMP_DIR/dry-run.out"

# Trailing slash in allowlist should behave the same.
(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$SAFE_ARCHIVE" RESTORE_ROOT="$TMP_DIR/restore" RESTORE_DRY_RUN=1 RESTORE_ALLOWED_PREFIXES='/root/.openclaw/' sh ./restore.sh > "$TMP_DIR/dry-run-slash.out"
)
grep -q 'preflight succeeded and no files were extracted' "$TMP_DIR/dry-run-slash.out"

# Archive with out-of-scope paths should be rejected.
UNSAFE_SRC="$TMP_DIR/unsafe-src"
mkdir -p "$UNSAFE_SRC/etc"
printf 'bad\n' > "$UNSAFE_SRC/etc/passwd"
UNSAFE_ARCHIVE="$TMP_DIR/unsafe.tar.gz"
(
  cd "$UNSAFE_SRC"
  tar -czf "$UNSAFE_ARCHIVE" .
)

set +e
(
  cd "$REPO_DIR"
  RESTORE_ARCHIVE="$UNSAFE_ARCHIVE" RESTORE_ROOT="$TMP_DIR/restore" RESTORE_ALLOWED_PREFIXES='/root/.openclaw' sh ./restore.sh > "$TMP_DIR/unsafe.out" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'outside RESTORE_ALLOWED_PREFIXES' "$TMP_DIR/unsafe.out"

echo 'restore_hardening_hermetic: ok'
