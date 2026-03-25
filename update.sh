#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"

GIT_PULL=${GIT_PULL:-auto}
RUN_BUILD=${RUN_BUILD:-1}
DRY_RUN=${DRY_RUN:-0}

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

usage() {
  cat <<'EOF2'
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

Notes:
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

load_ovh_api_key_from_env_file

if [ "$RUN_BUILD" = "1" ]; then
  log "Running build.sh to apply updates"
  if [ -n "$build_args" ]; then
    # shellcheck disable=SC2086
    run_cmd sh "$BUILD_SCRIPT" $build_args
  else
    run_cmd sh "$BUILD_SCRIPT"
  fi
else
  log "Skipping build.sh execution (RUN_BUILD=$RUN_BUILD)"
fi

log "Update workflow completed."
