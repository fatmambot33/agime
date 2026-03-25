#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

optional_tool_himalaya_prepare() {
  [ "$OPENCLAW_ENABLE_HIMALAYA_SKILL" = "1" ] || return 0

  log "Himalaya skill enabled; runtime dependency will be installed/validated inside Docker container after restart"
  optional_tool_himalaya_write_config_from_env

  if [ "$OPENCLAW_HIMALAYA_REQUIRE_CONFIG" = "1" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      log "[DRY_RUN] validate Himalaya config exists: $OPENCLAW_HIMALAYA_CONFIG_PATH"
      return 0
    fi

    [ -f "$OPENCLAW_HIMALAYA_CONFIG_PATH" ] ||
      fail "Himalaya config not found at '$OPENCLAW_HIMALAYA_CONFIG_PATH'. Run '$OPENCLAW_HIMALAYA_CLI_PATH account configure' and rerun build."
  fi
}

optional_tool_himalaya_write_config_from_env() {
  [ -n "${OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64:-}" ] || return 0

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] write Himalaya config from OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64 to $OPENCLAW_HIMALAYA_CONFIG_PATH"
    return 0
  fi

  require_command base64
  run_cmd mkdir -p "$(dirname "$OPENCLAW_HIMALAYA_CONFIG_PATH")"
  printf '%s' "$OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64" | base64 -d > "$OPENCLAW_HIMALAYA_CONFIG_PATH"
  run_cmd chmod 600 "$OPENCLAW_HIMALAYA_CONFIG_PATH"
}

optional_tool_himalaya_install_runtime() {
  [ "$OPENCLAW_ENABLE_HIMALAYA_SKILL" = "1" ] || return 0
  install_container_apt_package_if_missing himalaya "$OPENCLAW_HIMALAYA_CLI_PATH"
}

optional_tool_himalaya_validate_runtime() {
  [ "$OPENCLAW_ENABLE_HIMALAYA_SKILL" = "1" ] || return 0
  validate_container_binary "Himalaya skill prerequisites" "$OPENCLAW_HIMALAYA_CLI_PATH"
}
