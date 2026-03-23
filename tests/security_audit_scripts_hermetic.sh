#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
mkdir -p "$BIN_DIR"
DOCKER_CALLS="$TMP_DIR/docker_calls.log"
: > "$DOCKER_CALLS"
CRONTAB_STATE="$TMP_DIR/crontab.state"

cat > "$BIN_DIR/docker" << EOF
#!/usr/bin/env sh
printf 'docker %s\n' "\$*" >> "$DOCKER_CALLS"
if [ "\$1" = "exec" ] && [ "\$4" = "security" ] && [ "\$5" = "audit" ] && [ "\${6-}" = "--json" ]; then
  printf '{"ok":true}\n'
  exit 0
fi
printf 'ok %s\n' "\$*"
exit 0
EOF

cat > "$BIN_DIR/date" << 'EOF'
#!/usr/bin/env sh
if [ "$1" = "-u" ] && [ "$2" = "+%Y%m%dT%H%M%SZ" ]; then
  printf '20260323T000000Z\n'
  exit 0
fi
if [ "$1" = "-u" ] && [ "$2" = "+%Y-%m-%dT%H:%M:%SZ" ]; then
  printf '2026-03-23T00:00:00Z\n'
  exit 0
fi
exec /bin/date "$@"
EOF

cat > "$BIN_DIR/crontab" << EOF
#!/usr/bin/env sh
if [ "\$1" = "-l" ]; then
  if [ -f "$CRONTAB_STATE" ]; then
    cat "$CRONTAB_STATE"
    exit 0
  fi
  exit 1
fi
if [ "\$1" = "-" ]; then
  cat > "$CRONTAB_STATE"
  exit 0
fi
echo "unsupported crontab args: \$*" >&2
exit 1
EOF

chmod +x "$BIN_DIR/docker" "$BIN_DIR/date" "$BIN_DIR/crontab"

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    HOME="$TMP_DIR/home" \
    OPENCLAW_SECURITY_AUDIT_LOG_DIR="$TMP_DIR/audit-logs" \
    OPENCLAW_SECURITY_AUDIT_CONTAINER=test-openclaw \
    sh ./scripts/run_security_audit.sh
)

TEXT_LOG="$TMP_DIR/audit-logs/audit-20260323T000000Z.log"
JSON_LOG="$TMP_DIR/audit-logs/audit-20260323T000000Z.json"
[ -f "$TEXT_LOG" ]
[ -f "$JSON_LOG" ]
grep -Fq '"ok":true' "$JSON_LOG"
grep -Fq 'docker exec test-openclaw openclaw security audit --json' "$DOCKER_CALLS"

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    OPENCLAW_SECURITY_AUDIT_CRON_SCHEDULE="15 3 * * *" \
    OPENCLAW_SECURITY_AUDIT_CRON_TZ="Etc/UTC" \
    sh ./scripts/install_security_audit_cron.sh
)

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    OPENCLAW_SECURITY_AUDIT_CRON_SCHEDULE="15 3 * * *" \
    OPENCLAW_SECURITY_AUDIT_CRON_TZ="Etc/UTC" \
    sh ./scripts/install_security_audit_cron.sh
)

MARKER_COUNT=$(grep -c '^# agime-openclaw-security-audit$' "$CRONTAB_STATE")
[ "$MARKER_COUNT" -eq 1 ]
CRON_TZ_COUNT=$(grep -c '^CRON_TZ=Etc/UTC$' "$CRONTAB_STATE")
[ "$CRON_TZ_COUNT" -eq 1 ]
grep -Fq '15 3 * * * OPENCLAW_SECURITY_AUDIT_FIX=0 ' "$CRONTAB_STATE"
grep -Fq 'scripts/run_security_audit.sh # agime-openclaw-security-audit' "$CRONTAB_STATE"

echo "security audit scripts hermetic test passed"
