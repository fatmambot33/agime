#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

optional_tool_github_prepare() {
  [ "$OPENCLAW_ENABLE_GITHUB_SKILL" = "1" ] || return 0
  announce_container_runtime_validation_mode
  log "GitHub skill enabled; runtime dependency will be validated inside Docker container after restart"
}

optional_tool_github_install_runtime() {
  return 0
}

optional_tool_github_validate_runtime() {
  [ "$OPENCLAW_ENABLE_GITHUB_SKILL" = "1" ] || return 0
  validate_container_binary "GitHub skill prerequisites" "$OPENCLAW_GH_CLI_PATH"
  run_container_validation_command \
    "GitHub skill prerequisites" \
    "$OPENCLAW_GH_CLI_PATH --version" \
    sh -c '"$1" --version > /dev/null 2>&1' sh "$OPENCLAW_GH_CLI_PATH"
}

optional_tool_github_print_post_build_reminder() {
  [ "$OPENCLAW_ENABLE_GITHUB_SKILL" = "1" ] || return 0
  log "GitHub skill follow-up: authenticate inside the running container before using GitHub skill actions"
  log "  docker exec openclaw sh -lc '$OPENCLAW_GH_CLI_PATH auth login'"
  log "  docker exec openclaw sh -lc '$OPENCLAW_GH_CLI_PATH auth status'"
}
