#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"

GIT_PULL=${GIT_PULL:-1}
RUN_BUILD=${RUN_BUILD:-1}
BUILD_FLAGS=${BUILD_FLAGS:-}
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

usage() {
  cat <<'EOF2'
Usage:
  sh ./update.sh

Description:
  Post-install helper to update this toolkit checkout and optionally rerun build.sh
  with your existing environment variables.

Environment variables:
  GIT_PULL   Default: 1. Run `git pull --ff-only` in the repo before build.
  RUN_BUILD  Default: 1. Run build.sh after optional pull.
  BUILD_FLAGS Optional additional flags passed to build.sh (e.g. --help).
  DRY_RUN    Default: 0. Set to 1 to print actions only.
EOF2
}

[ "${1-}" = "--help" ] && {
  usage
  exit 0
}

[ -f "$BUILD_SCRIPT" ] || fail "build script not found at $BUILD_SCRIPT"

if [ "$GIT_PULL" = "1" ]; then
  if [ ! -d "$SCRIPT_DIR/.git" ]; then
    fail "git metadata not found at $SCRIPT_DIR/.git (cannot run GIT_PULL=1)"
  fi
  log "Updating toolkit checkout (git pull --ff-only)"
  run_cmd git -C "$SCRIPT_DIR" pull --ff-only
else
  log "Skipping repository update (GIT_PULL=$GIT_PULL)"
fi

if [ "$RUN_BUILD" = "1" ]; then
  log "Running build.sh to apply updates"
  # shellcheck disable=SC2086
  run_cmd sh "$BUILD_SCRIPT" $BUILD_FLAGS
else
  log "Skipping build.sh execution (RUN_BUILD=$RUN_BUILD)"
fi

log "Update workflow completed."
