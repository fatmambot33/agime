#!/usr/bin/env sh

set -eu

LOG_DIR=${OPENCLAW_SECURITY_AUDIT_LOG_DIR:-"$HOME/.openclaw/security-audit"}
RUN_FIX=${OPENCLAW_SECURITY_AUDIT_FIX:-"0"}
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
TEXT_LOG="$LOG_DIR/audit-$TIMESTAMP.log"
JSON_LOG="$LOG_DIR/audit-$TIMESTAMP.json"

mkdir -p "$LOG_DIR"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "openclaw command not found in PATH" >&2
  exit 1
fi

{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running: openclaw security audit"
  openclaw security audit

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running: openclaw security audit --deep"
  openclaw security audit --deep

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Writing JSON report: $JSON_LOG"
  openclaw security audit --json > "$JSON_LOG"

  if [ "$RUN_FIX" = "1" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running: openclaw security audit --fix"
    openclaw security audit --fix
  else
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Skipping --fix (set OPENCLAW_SECURITY_AUDIT_FIX=1 to enable)"
  fi
} | tee "$TEXT_LOG"
