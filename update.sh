#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
RESTORE_SCRIPT="$SCRIPT_DIR/restore.sh"

GIT_PULL=${GIT_PULL:-auto}
RUN_BUILD=${RUN_BUILD:-1}
DRY_RUN=${DRY_RUN:-0}
LOAD_DEPLOY_ENV=${LOAD_DEPLOY_ENV:-auto}
OPENCLAW_AUTO_ENV_FILE=${OPENCLAW_AUTO_ENV_FILE:-"$SCRIPT_DIR/.sync-build.env"}
RUN_BACKUP=${RUN_BACKUP:-1}
BACKUP_OUTPUT=${BACKUP_OUTPUT:-"$SCRIPT_DIR/openclaw-update-backup-$(date +%Y%m%d-%H%M%S).tar.gz"}
RUN_IMAGE_PULL=${RUN_IMAGE_PULL:-auto}
RESTORE_ON_FAILURE=${RESTORE_ON_FAILURE:-0}
LAST_BACKUP_ARCHIVE=

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] $*"
    return 0
  fi
  "$@"
}

load_ovh_api_key_from_env_file() {
  [ -n "${OVH_ENDPOINT_API_KEY:-}" ] && return 0

  openclaw_dir=${OPENCLAW_DIR:-"$HOME/openclaw"}
  env_file="$openclaw_dir/.env"
  [ -f "$env_file" ] || return 0

  api_key=$(awk -F= '/^[[:space:]]*OVH_ENDPOINT_API_KEY=/{sub(/^[[:space:]]*OVH_ENDPOINT_API_KEY=/,""); print; exit}' "$env_file")
  [ -n "$api_key" ] || return 0

  OVH_ENDPOINT_API_KEY=$api_key
  export OVH_ENDPOINT_API_KEY
  log "Loaded OVH_ENDPOINT_API_KEY from $env_file"
}

load_deploy_env_file() {
  case "$LOAD_DEPLOY_ENV" in
    auto)
      if [ -f "$OPENCLAW_AUTO_ENV_FILE" ]; then
        # shellcheck disable=SC1090
        set -a && . "$OPENCLAW_AUTO_ENV_FILE" && set +a
        log "Loaded deployment defaults from $OPENCLAW_AUTO_ENV_FILE"
      else
        log "Skipping deployment-default load (missing $OPENCLAW_AUTO_ENV_FILE; LOAD_DEPLOY_ENV=auto)"
      fi
      ;;
    1)
      [ -f "$OPENCLAW_AUTO_ENV_FILE" ] || fail "deployment env file not found at $OPENCLAW_AUTO_ENV_FILE (LOAD_DEPLOY_ENV=1)"
      # shellcheck disable=SC1090
      set -a && . "$OPENCLAW_AUTO_ENV_FILE" && set +a
      log "Loaded deployment defaults from $OPENCLAW_AUTO_ENV_FILE"
      ;;
    0)
      log "Skipping deployment-default load (LOAD_DEPLOY_ENV=0)"
      ;;
    *)
      fail "unsupported LOAD_DEPLOY_ENV='$LOAD_DEPLOY_ENV' (expected: auto, 1, 0)"
      ;;
  esac
}

run_pre_update_backup() {
  case "$RUN_BACKUP" in
    1)
      [ -f "$BACKUP_SCRIPT" ] || fail "backup script not found at $BACKUP_SCRIPT"
      log "Creating pre-update backup at $BACKUP_OUTPUT"
      LAST_BACKUP_ARCHIVE=$BACKUP_OUTPUT
      run_cmd env BACKUP_OUTPUT="$BACKUP_OUTPUT" sh "$BACKUP_SCRIPT"
      ;;
    0)
      log "Skipping pre-update backup (RUN_BACKUP=0)"
      ;;
    *)
      fail "unsupported RUN_BACKUP='$RUN_BACKUP' (expected: 1 or 0)"
      ;;
  esac
}

run_image_pull() {
  do_pull=0
  case "$RUN_IMAGE_PULL" in
    auto)
      if [ "${SKIP_OPENCLAW_IMAGE_BUILD:-0}" = "1" ] && [ -n "${OPENCLAW_IMAGE:-}" ]; then
        do_pull=1
      fi
      ;;
    1)
      do_pull=1
      ;;
    0)
      do_pull=0
      ;;
    *)
      fail "unsupported RUN_IMAGE_PULL='$RUN_IMAGE_PULL' (expected: auto, 1, 0)"
      ;;
  esac

  [ "$do_pull" = "1" ] || {
    log "Skipping image pull (RUN_IMAGE_PULL=$RUN_IMAGE_PULL)"
    return 0
  }

  [ -n "${OPENCLAW_IMAGE:-}" ] || fail "OPENCLAW_IMAGE must be set when image pull is enabled"
  if ! command -v docker > /dev/null 2>&1; then
    fail "docker CLI not found in PATH (required for RUN_IMAGE_PULL=$RUN_IMAGE_PULL)"
  fi
  log "Pulling OpenClaw image: $OPENCLAW_IMAGE"
  run_cmd docker pull "$OPENCLAW_IMAGE"
}

restore_after_failed_build() {
  [ "$RESTORE_ON_FAILURE" = "1" ] || return 0
  [ -f "$RESTORE_SCRIPT" ] || fail "restore script not found at $RESTORE_SCRIPT"

  archive=${RESTORE_ARCHIVE:-$LAST_BACKUP_ARCHIVE}
  [ -n "$archive" ] || fail "RESTORE_ON_FAILURE=1 requires RESTORE_ARCHIVE or RUN_BACKUP=1"

  log "Build failed; restoring from $archive (RESTORE_ON_FAILURE=1)"
  run_cmd env RESTORE_ARCHIVE="$archive" sh "$RESTORE_SCRIPT"
}

usage() {
  cat << 'EOF2'
Usage:
  sh ./update.sh
  sh ./update.sh -- --help

Description:
  Post-install helper to update this toolkit checkout and optionally rerun build.sh.

Environment variables:
  GIT_PULL   Default: auto. One of:
             - auto: run git pull only when this directory is a git checkout.
             - 1: force git pull --ff-only (fails when .git is missing).
             - 0: skip git pull.
  RUN_BUILD  Default: 1. Run build.sh after optional pull.
  DRY_RUN    Default: 0. Set to 1 to print actions only.
  RUN_BACKUP Default: 1. Run backup.sh before update/deploy.
  BACKUP_OUTPUT Default: timestamped archive path under script directory.
  RUN_IMAGE_PULL Default: auto. One of:
             - auto: pull OPENCLAW_IMAGE when SKIP_OPENCLAW_IMAGE_BUILD=1.
             - 1: always pull OPENCLAW_IMAGE before build.sh.
             - 0: skip docker pull.
  RESTORE_ON_FAILURE Default: 0. When 1, run restore.sh if build.sh fails.
             Uses RESTORE_ARCHIVE when set; otherwise uses BACKUP_OUTPUT
             from this update run when RUN_BACKUP=1.
  LOAD_DEPLOY_ENV Default: auto. One of:
             - auto: source OPENCLAW_AUTO_ENV_FILE when it exists.
             - 1: require and source OPENCLAW_AUTO_ENV_FILE.
             - 0: skip sourcing deployment defaults file.
  OPENCLAW_AUTO_ENV_FILE Default: ./.sync-build.env relative to this script.

Notes:
  - Easy update flow default is: backup -> optional image pull -> build/deploy.
  - Deployment defaults (including OPENCLAW_IMAGE / SKIP_OPENCLAW_IMAGE_BUILD)
    can be sourced from OPENCLAW_AUTO_ENV_FILE before running build.sh.
  - If OVH_ENDPOINT_API_KEY is unset, this script attempts to load it from
    ${OPENCLAW_DIR:-$HOME/openclaw}/.env (when present).
  - Extra arguments after `--` are passed to build.sh.
EOF2
}

[ "${1-}" = "--help" ] && {
  usage
  exit 0
}

[ -f "$BUILD_SCRIPT" ] || fail "build script not found at $BUILD_SCRIPT"

build_args=
if [ "${1-}" = "--" ]; then
  shift
  build_args="$*"
fi

case "$GIT_PULL" in
  auto)
    if [ -d "$SCRIPT_DIR/.git" ]; then
      log "Updating toolkit checkout (git pull --ff-only)"
      run_cmd git -C "$SCRIPT_DIR" pull --ff-only
    else
      log "Skipping repository update (no .git checkout found; GIT_PULL=auto)"
    fi
    ;;
  1)
    [ -d "$SCRIPT_DIR/.git" ] || fail "git metadata not found at $SCRIPT_DIR/.git (cannot run GIT_PULL=1)"
    log "Updating toolkit checkout (git pull --ff-only)"
    run_cmd git -C "$SCRIPT_DIR" pull --ff-only
    ;;
  0)
    log "Skipping repository update (GIT_PULL=0)"
    ;;
  *)
    fail "unsupported GIT_PULL='$GIT_PULL' (expected: auto, 1, 0)"
    ;;
esac

load_deploy_env_file
load_ovh_api_key_from_env_file
run_pre_update_backup
run_image_pull

if [ "$RUN_BUILD" = "1" ]; then
  log "Running build.sh to apply updates"
  if [ -n "$build_args" ]; then
    # shellcheck disable=SC2086
    if ! run_cmd sh "$BUILD_SCRIPT" $build_args; then
      restore_after_failed_build
      fail "build.sh failed during update workflow"
    fi
  else
    if ! run_cmd sh "$BUILD_SCRIPT"; then
      restore_after_failed_build
      fail "build.sh failed during update workflow"
    fi
  fi
else
  log "Skipping build.sh execution (RUN_BUILD=$RUN_BUILD)"
fi

log "Update workflow completed."
