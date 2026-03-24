#!/usr/bin/env sh

set -eu

OPENCLAW_DIR=${OPENCLAW_DIR:-"$HOME/openclaw"}
OPENCLAW_CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-"$HOME/.openclaw"}
TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME/docker/traefik"}
INCLUDE_TRAEFIK=${INCLUDE_TRAEFIK:-0}
BACKUP_OUTPUT=${BACKUP_OUTPUT:-"$PWD/openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
STAGE_DIR="$TMP_DIR/stage"
mkdir -p "$STAGE_DIR"

COPIED_COUNT=0

copy_path() {
  src_path=$1
  if [ ! -e "$src_path" ]; then
    echo "[skip] missing: $src_path"
    return 0
  fi

  parent_dir=$(dirname "$src_path")
  mkdir -p "$STAGE_DIR$parent_dir"
  cp -a "$src_path" "$STAGE_DIR$src_path"
  COPIED_COUNT=$((COPIED_COUNT + 1))
  echo "[add] $src_path"
}

copy_path "$OPENCLAW_CONFIG_DIR"
copy_path "$OPENCLAW_DIR/.env"

if [ "$INCLUDE_TRAEFIK" = "1" ]; then
  copy_path "$TRAEFIK_DIR"
fi

if [ "$COPIED_COUNT" -eq 0 ]; then
  echo "No backup sources were found. Nothing to archive." >&2
  exit 1
fi

mkdir -p "$(dirname "$BACKUP_OUTPUT")"
(
  cd "$STAGE_DIR"
  tar -czf "$BACKUP_OUTPUT" .
)

echo "Backup written to: $BACKUP_OUTPUT"
