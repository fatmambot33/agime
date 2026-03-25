#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$REPO_DIR/build-interactive.sh" "$TMP_DIR/build-interactive.sh"
chmod +x "$TMP_DIR/build-interactive.sh"

cat > "$TMP_DIR/build.sh" << 'EOF'
#!/usr/bin/env sh
set -eu
printf '%s\n' "build-ran" > "$TMP_DIR/build.called"
printf '%s\n' "OVH_ENDPOINT_API_KEY=${OVH_ENDPOINT_API_KEY:-}" > "$TMP_DIR/build.env"
EOF
chmod +x "$TMP_DIR/build.sh"

cat > "$TMP_DIR/.sync-build.env" << 'EOF'
OVH_ENDPOINT_API_KEY=from-env-file
EOF

(
  cd "$TMP_DIR"
  TMP_DIR="$TMP_DIR" sh ./build-interactive.sh
)

grep -Fq "build-ran" "$TMP_DIR/build.called"
grep -Fq "OVH_ENDPOINT_API_KEY=from-env-file" "$TMP_DIR/build.env"

echo "build-interactive env auto-load hermetic test passed"
