#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

optional_tool_github_prepare() {
  [ "$OPENCLAW_ENABLE_GITHUB_SKILL" = "1" ] || return 0
  log "GitHub skill enabled; runtime dependency will be installed/validated inside Docker container after restart"
}

optional_tool_github_install_runtime() {
  [ "$OPENCLAW_ENABLE_GITHUB_SKILL" = "1" ] || return 0
  install_container_apt_package_if_missing gh "$OPENCLAW_GH_CLI_PATH"
}

optional_tool_github_validate_runtime() {
  [ "$OPENCLAW_ENABLE_GITHUB_SKILL" = "1" ] || return 0
  validate_container_binary "GitHub skill prerequisites" "$OPENCLAW_GH_CLI_PATH"
}
