#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

install_container_apt_package_if_missing() {
  package_name=$1
  binary_name=$2

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] ensure container package '$package_name' provides binary '$binary_name'"
    return 0
  fi

  if docker exec openclaw sh -c 'command -v "$1" > /dev/null 2>&1' sh "$binary_name"; then
    return 0
  fi

  log "Installing '$package_name' inside openclaw container for optional skill runtime"
  docker exec -u 0 openclaw sh -c 'if command -v apt-get > /dev/null 2>&1; then apt-get update && apt-get install -y "$1"; else exit 127; fi' sh "$package_name" ||
    fail "Unable to install '$package_name' inside openclaw container. Build a custom OPENCLAW_IMAGE with '$binary_name' available."
}

install_container_npm_package_if_missing() {
  npm_package=$1
  binary_name=$2

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] ensure container npm package '$npm_package' provides binary '$binary_name'"
    return 0
  fi

  if docker exec openclaw sh -c 'command -v "$1" > /dev/null 2>&1' sh "$binary_name"; then
    return 0
  fi

  log "Installing npm package '$npm_package' inside openclaw container for optional skill runtime"
  docker exec -u 0 openclaw sh -c 'if command -v npm > /dev/null 2>&1; then npm i -g "$1"; else exit 127; fi' sh "$npm_package" ||
    fail "Unable to install npm package '$npm_package' inside openclaw container. Build a custom OPENCLAW_IMAGE with '$binary_name' available."
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
