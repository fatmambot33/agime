#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"

TOOL=${TOOL:-${1:-}}
DRY_RUN=${DRY_RUN:-0}

OPENCLAW_ENABLE_SIGNAL=${OPENCLAW_ENABLE_SIGNAL:-0}
OPENCLAW_ENABLE_GITHUB_SKILL=${OPENCLAW_ENABLE_GITHUB_SKILL:-0}
OPENCLAW_ENABLE_HIMALAYA_SKILL=${OPENCLAW_ENABLE_HIMALAYA_SKILL:-0}
OPENCLAW_ENABLE_CODING_AGENT_SKILL=${OPENCLAW_ENABLE_CODING_AGENT_SKILL:-0}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF2'
Usage:
  TOOL=github sh ./add_tool.sh
  sh ./add_tool.sh signal

Description:
  Post-install helper to enable one optional runtime tool by setting the
  corresponding OPENCLAW_ENABLE_* variable and rerunning build.sh.

Supported tools:
  signal | github | himalaya | coding-agent

Notes:
  - You must still provide any required variables for the selected tool
    (e.g. OPENCLAW_SIGNAL_ACCOUNT for signal).
  - Existing OPENCLAW_ENABLE_* environment variables are preserved unless
    overridden by TOOL.
  - Set DRY_RUN=1 to preview actions only.
EOF2
}

[ "${1-}" = "--help" ] && {
  usage
  exit 0
}

[ -f "$BUILD_SCRIPT" ] || fail "build script not found at $BUILD_SCRIPT"
[ -n "$TOOL" ] || fail "missing TOOL. Run 'sh ./add_tool.sh --help'"

case "$TOOL" in
  signal)
    OPENCLAW_ENABLE_SIGNAL=1
    ;;
  github)
    OPENCLAW_ENABLE_GITHUB_SKILL=1
    ;;
  himalaya)
    OPENCLAW_ENABLE_HIMALAYA_SKILL=1
    ;;
  coding-agent)
    OPENCLAW_ENABLE_CODING_AGENT_SKILL=1
    ;;
  *)
    fail "unsupported TOOL='$TOOL' (expected: signal, github, himalaya, coding-agent)"
    ;;
esac

log "Enabling optional tool: $TOOL"
log "  OPENCLAW_ENABLE_SIGNAL=$OPENCLAW_ENABLE_SIGNAL"
log "  OPENCLAW_ENABLE_GITHUB_SKILL=$OPENCLAW_ENABLE_GITHUB_SKILL"
log "  OPENCLAW_ENABLE_HIMALAYA_SKILL=$OPENCLAW_ENABLE_HIMALAYA_SKILL"
log "  OPENCLAW_ENABLE_CODING_AGENT_SKILL=$OPENCLAW_ENABLE_CODING_AGENT_SKILL"

if [ "$DRY_RUN" = "1" ]; then
  log "[DRY_RUN] sh $BUILD_SCRIPT"
  exit 0
fi

OPENCLAW_ENABLE_SIGNAL=$OPENCLAW_ENABLE_SIGNAL \
OPENCLAW_ENABLE_GITHUB_SKILL=$OPENCLAW_ENABLE_GITHUB_SKILL \
OPENCLAW_ENABLE_HIMALAYA_SKILL=$OPENCLAW_ENABLE_HIMALAYA_SKILL \
OPENCLAW_ENABLE_CODING_AGENT_SKILL=$OPENCLAW_ENABLE_CODING_AGENT_SKILL \
sh "$BUILD_SCRIPT"
