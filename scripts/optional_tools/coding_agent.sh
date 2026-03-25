#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

optional_tool_coding_agent_prepare() {
  [ "$OPENCLAW_ENABLE_CODING_AGENT_SKILL" = "1" ] || return 0

  case "$OPENCLAW_CODING_AGENT_BACKEND" in
    claude) OPENCLAW_CODING_AGENT_BIN=claude ;;
    codex) OPENCLAW_CODING_AGENT_BIN=codex ;;
    pi) OPENCLAW_CODING_AGENT_BIN=pi ;;
    opencode) OPENCLAW_CODING_AGENT_BIN=opencode ;;
    *) fail "Unsupported coding-agent backend: $OPENCLAW_CODING_AGENT_BACKEND" ;;
  esac

  log "Coding-agent skill enabled; backend '$OPENCLAW_CODING_AGENT_BACKEND' will be installed/validated inside Docker container after restart"
}

optional_tool_coding_agent_install_runtime() {
  [ "$OPENCLAW_ENABLE_CODING_AGENT_SKILL" = "1" ] || return 0

  case "$OPENCLAW_CODING_AGENT_BACKEND" in
    claude)
      install_container_npm_package_if_missing @anthropic-ai/claude-code "$OPENCLAW_CODING_AGENT_BIN"
      ;;
    codex)
      install_container_npm_package_if_missing @openai/codex "$OPENCLAW_CODING_AGENT_BIN"
      ;;
    pi)
      install_container_npm_package_if_missing @mariozechner/pi-coding-agent "$OPENCLAW_CODING_AGENT_BIN"
      ;;
    opencode) ;;
  esac
}

optional_tool_coding_agent_validate_runtime() {
  [ "$OPENCLAW_ENABLE_CODING_AGENT_SKILL" = "1" ] || return 0
  validate_container_binary "coding-agent skill prerequisites" "$OPENCLAW_CODING_AGENT_BIN"

  run_container_validation_command \
    "coding-agent skill prerequisites" \
    "$OPENCLAW_CODING_AGENT_BIN --version" \
    sh -c '"$1" --version > /dev/null 2>&1' sh "$OPENCLAW_CODING_AGENT_BIN"
}
