#!/usr/bin/env sh

set -eu

RESTORE_ARCHIVE=${RESTORE_ARCHIVE:-${1:-}}
RESTORE_ROOT=${RESTORE_ROOT:-/}
RESTORE_FORCE=${RESTORE_FORCE:-0}

fail() {
  echo "$*" >&2
  exit 1
}

if [ -z "$RESTORE_ARCHIVE" ]; then
  fail "Usage: RESTORE_ARCHIVE=/path/to/openclaw-backup.tar.gz [RESTORE_ROOT=/] [RESTORE_FORCE=1] sh restore.sh"
fi

if [ ! -f "$RESTORE_ARCHIVE" ]; then
  fail "Archive not found: $RESTORE_ARCHIVE"
fi

mkdir -p "$RESTORE_ROOT"
RESTORE_ROOT=$(CDPATH= cd -- "$RESTORE_ROOT" && pwd -P)

if [ "$RESTORE_ROOT" = "/" ] && [ "$RESTORE_FORCE" != "1" ]; then
  fail "Refusing to restore into / without RESTORE_FORCE=1"
fi

TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST"' EXIT
tar -tzf "$RESTORE_ARCHIVE" > "$TMP_LIST"

UNSAFE_ENTRY=""
while IFS= read -r entry; do
  case "$entry" in
    /* | .. | ../* | */../* | */..)
      UNSAFE_ENTRY=$entry
      break
      ;;
  esac
done < "$TMP_LIST"

[ -z "$UNSAFE_ENTRY" ] || fail "Refusing to restore archive with unsafe path entry: $UNSAFE_ENTRY"

echo "Restoring archive: $RESTORE_ARCHIVE"
echo "Destination root: $RESTORE_ROOT"
tar -xzf "$RESTORE_ARCHIVE" -C "$RESTORE_ROOT"

echo "Restore completed."
