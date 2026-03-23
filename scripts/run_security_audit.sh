#!/usr/bin/env sh

set -eu

LOG_DIR=${OPENCLAW_SECURITY_AUDIT_LOG_DIR:-"$HOME/.openclaw/security-audit"}
RUN_FIX=${OPENCLAW_SECURITY_AUDIT_FIX:-"0"}
OPENCLAW_SECURITY_AUDIT_RUNNER=${OPENCLAW_SECURITY_AUDIT_RUNNER:-"container"}
OPENCLAW_SECURITY_AUDIT_CONTAINER=${OPENCLAW_SECURITY_AUDIT_CONTAINER:-"openclaw"}
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
TEXT_LOG="$LOG_DIR/audit-$TIMESTAMP.log"
JSON_LOG="$LOG_DIR/audit-$TIMESTAMP.json"

mkdir -p "$LOG_DIR"
: > "$TEXT_LOG"

log_msg() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" | tee -a "$TEXT_LOG"
}

run_openclaw_cmd() {
  if [ "$OPENCLAW_SECURITY_AUDIT_RUNNER" = "host" ]; then
    if ! command -v openclaw > /dev/null 2>&1; then
      echo "openclaw command not found in PATH (set OPENCLAW_SECURITY_AUDIT_RUNNER=container or install CLI)" >&2
      return 1
    fi
    openclaw "$@"
    return $?
  fi

  if ! command -v docker > /dev/null 2>&1; then
    echo "docker command not found in PATH (required for container audit runner)" >&2
    return 1
  fi
  docker exec "$OPENCLAW_SECURITY_AUDIT_CONTAINER" openclaw "$@"
}

run_and_capture() {
  DESCRIPTION=$1
  shift
  OUTPUT_FILE=$(mktemp)
  if run_openclaw_cmd "$@" > "$OUTPUT_FILE" 2>&1; then
    :
  else
    STATUS=$?
    cat "$OUTPUT_FILE" | tee -a "$TEXT_LOG"
    rm -f "$OUTPUT_FILE"
    return "$STATUS"
  fi
  cat "$OUTPUT_FILE" | tee -a "$TEXT_LOG"
  rm -f "$OUTPUT_FILE"
  log_msg "Completed: $DESCRIPTION"
}

log_msg "Runner mode: $OPENCLAW_SECURITY_AUDIT_RUNNER"
if [ "$OPENCLAW_SECURITY_AUDIT_RUNNER" != "host" ]; then
  log_msg "Container target: $OPENCLAW_SECURITY_AUDIT_CONTAINER"
fi

log_msg "Running: openclaw security audit"
run_and_capture "openclaw security audit" security audit

log_msg "Running: openclaw security audit --deep"
run_and_capture "openclaw security audit --deep" security audit --deep

log_msg "Writing JSON report: $JSON_LOG"
run_openclaw_cmd security audit --json > "$JSON_LOG"
log_msg "Completed: openclaw security audit --json"

if [ "$RUN_FIX" = "1" ]; then
  log_msg "Running: openclaw security audit --fix"
  run_and_capture "openclaw security audit --fix" security audit --fix
else
  log_msg "Skipping --fix (set OPENCLAW_SECURITY_AUDIT_FIX=1 to enable)"
fi
