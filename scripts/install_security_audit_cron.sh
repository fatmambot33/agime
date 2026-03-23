#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUNNER=${RUNNER:-"$SCRIPT_DIR/run_security_audit.sh"}
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 3 * * *"}
CRON_CMD="$CRON_SCHEDULE $RUNNER"

[ -x "$RUNNER" ] || chmod +x "$RUNNER"

if ! command -v crontab > /dev/null 2>&1; then
  echo "crontab command not found; cannot install scheduled audit" >&2
  exit 1
fi

CURRENT_CRON=$(mktemp)
trap 'rm -f "$CURRENT_CRON"' EXIT

if crontab -l > "$CURRENT_CRON" 2> /dev/null; then
  :
else
  : > "$CURRENT_CRON"
fi

if ! grep -Fq "$RUNNER" "$CURRENT_CRON"; then
  printf '%s\n' "$CRON_CMD" >> "$CURRENT_CRON"
  crontab "$CURRENT_CRON"
  echo "Installed cron entry: $CRON_CMD"
else
  echo "Cron entry already present for $RUNNER"
fi
