#!/usr/bin/env sh

set -eu

RESTORE_ARCHIVE=${RESTORE_ARCHIVE:-${1:-}}
RESTORE_ROOT=${RESTORE_ROOT:-/}
RESTORE_FORCE=${RESTORE_FORCE:-0}
RESTORE_DRY_RUN=${RESTORE_DRY_RUN:-0}
RESTORE_ALLOW_LINKS=${RESTORE_ALLOW_LINKS:-0}
RESTORE_ALLOWED_PREFIXES=${RESTORE_ALLOWED_PREFIXES:-"$HOME/.openclaw $HOME/openclaw $HOME/docker/traefik"}

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
TMP_TAR_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST" "$TMP_TAR_LIST"' EXIT
tar -tzf "$RESTORE_ARCHIVE" > "$TMP_LIST"
tar -tvzf "$RESTORE_ARCHIVE" > "$TMP_TAR_LIST"

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

if [ "$RESTORE_ALLOW_LINKS" != "1" ] && awk '($1 ~ /^[lh]/) { found = 1 } END { exit(found ? 0 : 1) }' "$TMP_TAR_LIST"; then
  fail "Refusing archive with symlink/hardlink entries unless RESTORE_ALLOW_LINKS=1"
fi

entry_out_of_scope=""
while IFS= read -r entry; do
  case "$entry" in
    '' | '.' | './') continue ;;
  esac

  normalized=$entry
  while :; do
    case "$normalized" in
      ./*) normalized=${normalized#./} ;;
      *) break ;;
    esac
  done
  [ -n "$normalized" ] || continue
  normalized="/$normalized"
  while [ "$normalized" != "/" ] && [ "${normalized%/}" != "$normalized" ]; do
    normalized=${normalized%/}
  done

  allowed=0
  for prefix in $RESTORE_ALLOWED_PREFIXES; do
    case "$normalized" in
      "$prefix" | "$prefix"/*)
        allowed=1
        break
        ;;
    esac
    case "$prefix" in
      "$normalized"/*)
        allowed=1
        break
        ;;
    esac
  done

  if [ "$allowed" != "1" ]; then
    entry_out_of_scope=$normalized
    break
  fi
done < "$TMP_LIST"

[ -z "$entry_out_of_scope" ] || fail "Refusing restore entry outside RESTORE_ALLOWED_PREFIXES: $entry_out_of_scope"

echo "Restoring archive: $RESTORE_ARCHIVE"
echo "Destination root: $RESTORE_ROOT"
echo "Allowed restore prefixes: $RESTORE_ALLOWED_PREFIXES"
if [ "$RESTORE_DRY_RUN" = "1" ]; then
  echo "RESTORE_DRY_RUN=1 set; preflight succeeded and no files were extracted."
  exit 0
fi
tar -xzf "$RESTORE_ARCHIVE" -C "$RESTORE_ROOT"

echo "Restore completed."
