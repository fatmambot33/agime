#!/usr/bin/env sh

set -eu

LOG_DIR=${LOG_DIR:-"$HOME/.openclaw/security-audit"}
TS=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/audit-$TS.log"

mkdir -p "$LOG_DIR"

if ! command -v openclaw > /dev/null 2>&1; then
  echo "openclaw command not found in PATH" >&2
  exit 1
fi

openclaw security audit > "$LOG_FILE" 2>&1

echo "Security audit report written to: $LOG_FILE"
