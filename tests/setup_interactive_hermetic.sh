#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

WORK_DIR="$TMP_DIR/work"
mkdir -p "$WORK_DIR"
cp "$REPO_DIR/setup.sh" "$WORK_DIR/setup.sh"
chmod +x "$WORK_DIR/setup.sh"

cat > "$WORK_DIR/sync.sh" <<'EOF_SYNC'
#!/usr/bin/env sh
set -eu
: "${SYNC_CONFIG_FILE:?missing sync config path}"
cp "$SYNC_CONFIG_FILE" "${SYNC_CONFIG_CAPTURE:?missing capture path}"
EOF_SYNC
chmod +x "$WORK_DIR/sync.sh"

SYNC_CONFIG_CAPTURE="$TMP_DIR/sync.conf"
(
  cd "$WORK_DIR"
  REMOTE_HOST='ubuntu@example' \
  REMOTE_DIR='~/deploy' \
  SYNC_CONFIG_CAPTURE="$SYNC_CONFIG_CAPTURE" \
  sh ./setup.sh <<'EOF_INPUT'

api-key-123

y
EOF_INPUT
)

grep -Fxq 'OPENCLAW_ACCESS_MODE=ssh-tunnel' "$SYNC_CONFIG_CAPTURE"
grep -Fxq 'OVH_ENDPOINT_API_KEY=api-key-123' "$SYNC_CONFIG_CAPTURE"
grep -Fxq 'OPENCLAW_TOKEN=' "$SYNC_CONFIG_CAPTURE"

echo "setup_interactive_hermetic test passed"
