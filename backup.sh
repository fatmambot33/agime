#!/usr/bin/env sh

set -eu

OPENCLAW_DIR=${OPENCLAW_DIR:-"$HOME/openclaw"}
OPENCLAW_CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-"$HOME/.openclaw"}
OPENCLAW_WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR:-"$OPENCLAW_CONFIG_DIR/workspace"}
OPENCLAW_SKILLS_DIR=${OPENCLAW_SKILLS_DIR:-"$OPENCLAW_CONFIG_DIR/skills"}
OPENCLAW_HOOKS_DIR=${OPENCLAW_HOOKS_DIR:-"$OPENCLAW_CONFIG_DIR/hooks"}
OPENCLAW_PAIRED_DEVICES_PATH=${OPENCLAW_PAIRED_DEVICES_PATH:-"$OPENCLAW_CONFIG_DIR/paired-devices.json"}
TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME/docker/traefik"}
INCLUDE_TRAEFIK=${INCLUDE_TRAEFIK:-0}
INCLUDE_OPENCLAW_REPO=${INCLUDE_OPENCLAW_REPO:-0}
EXTRA_BACKUP_PATHS=${EXTRA_BACKUP_PATHS:-}
BACKUP_OUTPUT=${BACKUP_OUTPUT:-"$PWD/openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"}

case "$BACKUP_OUTPUT" in
  /*) ;;
  *)
    BACKUP_OUTPUT="$PWD/$BACKUP_OUTPUT"
    ;;
esac

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

  case "$src_path" in
    /*) src_abs=$src_path ;;
    *) src_abs=$PWD/$src_path ;;
  esac
  dest_path=$STAGE_DIR$src_abs

  if [ -d "$src_abs" ]; then
    mkdir -p "$dest_path"
    cp -a "$src_abs"/. "$dest_path"/
  else
    parent_dir=$(dirname "$src_abs")
    mkdir -p "$STAGE_DIR$parent_dir"
    cp -a "$src_abs" "$dest_path"
  fi
  COPIED_COUNT=$((COPIED_COUNT + 1))
  echo "[add] $src_path"
}

copy_path "$OPENCLAW_CONFIG_DIR"
copy_path "$OPENCLAW_WORKSPACE_DIR"
copy_path "$OPENCLAW_SKILLS_DIR"
copy_path "$OPENCLAW_HOOKS_DIR"
copy_path "$OPENCLAW_PAIRED_DEVICES_PATH"
copy_path "$OPENCLAW_DIR/.env"
copy_path "$OPENCLAW_DIR/docker-compose.yml"

if [ "$INCLUDE_TRAEFIK" = "1" ]; then
  copy_path "$TRAEFIK_DIR"
fi

if [ "$INCLUDE_OPENCLAW_REPO" = "1" ]; then
  copy_path "$OPENCLAW_DIR"
fi

if [ -n "$EXTRA_BACKUP_PATHS" ]; then
  for extra_path in $EXTRA_BACKUP_PATHS; do
    copy_path "$extra_path"
  done
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
