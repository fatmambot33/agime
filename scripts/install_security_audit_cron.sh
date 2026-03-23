#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUNNER="$SCRIPT_DIR/run_security_audit.sh"
CRON_SCHEDULE=${OPENCLAW_SECURITY_AUDIT_CRON_SCHEDULE:-"0 12 * * *"}
CRON_MARKER="# agime-openclaw-security-audit"
CRON_TIMEZONE=${OPENCLAW_SECURITY_AUDIT_CRON_TZ:-"Etc/GMT"}

[ -x "$RUNNER" ] || chmod +x "$RUNNER"

if ! command -v crontab >/dev/null 2>&1; then
  echo "crontab command not found; cannot install scheduled audit" >&2
  exit 1
fi

CURRENT_CRON=$(mktemp)
trap 'rm -f "$CURRENT_CRON"' EXIT

if crontab -l > "$CURRENT_CRON" 2>/dev/null; then
  :
else
  : > "$CURRENT_CRON"
fi

FILTERED_CRON=$(mktemp)
trap 'rm -f "$CURRENT_CRON" "$FILTERED_CRON"' EXIT
grep -v 'agime-openclaw-security-audit' "$CURRENT_CRON" > "$FILTERED_CRON" || true

{
  cat "$FILTERED_CRON"
  echo "CRON_TZ=$CRON_TIMEZONE $CRON_MARKER"
  echo "$CRON_SCHEDULE OPENCLAW_SECURITY_AUDIT_FIX=0 $RUNNER $CRON_MARKER"
} | crontab -

echo "Installed OpenClaw security audit cron:"
echo "  CRON_TZ=$CRON_TIMEZONE"
echo "  $CRON_SCHEDULE OPENCLAW_SECURITY_AUDIT_FIX=0 $RUNNER"
echo "To enable --fix in cron, edit crontab and set OPENCLAW_SECURITY_AUDIT_FIX=1 (use with caution)."
