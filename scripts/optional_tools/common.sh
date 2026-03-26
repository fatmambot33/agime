#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

announce_container_runtime_validation_mode() {
  log "Optional tools use image-first runtime validation (binaries must exist in OPENCLAW_IMAGE)"
}

validate_container_binary() {
  feature_name=$1
  binary_name=$2

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] validate $feature_name runtime binary inside openclaw container: $binary_name"
    return 0
  fi

  if ! docker exec openclaw sh -c 'command -v "$1" > /dev/null 2>&1' sh "$binary_name"; then
    fail "$feature_name is enabled, but '$binary_name' is not available inside the openclaw container runtime. Install it in the OpenClaw image or disable this optional feature."
  fi
}

run_container_validation_command() {
  feature_name=$1
  validation_description=$2
  shift 2

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] validate $feature_name runtime command inside openclaw container: $validation_description"
    return 0
  fi

  if ! docker exec openclaw "$@"; then
    fail "$feature_name is enabled, but runtime validation failed: $validation_description"
  fi
}
