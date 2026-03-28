#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

WORK_DIR="$TMP_DIR/work"
HOME_DIR="$TMP_DIR/home"
mkdir -p "$WORK_DIR" "$HOME_DIR"

cp "$REPO_DIR/configure.sh" "$WORK_DIR/configure.sh"
chmod +x "$WORK_DIR/configure.sh"

CALLS_FILE="$TMP_DIR/image.env"
OUTPUT_FILE="$TMP_DIR/configure.out"

cat > "$WORK_DIR/image.sh" << EOF_IMAGE
#!/usr/bin/env sh
set -eu
printf 'CUSTOM_OPENCLAW_IMAGE=%s\n' "\${CUSTOM_OPENCLAW_IMAGE:-}" > "$CALLS_FILE"
printf 'CUSTOM_OPENCLAW_PUSH=%s\n' "\${CUSTOM_OPENCLAW_PUSH:-}" >> "$CALLS_FILE"
EOF_IMAGE
chmod +x "$WORK_DIR/image.sh"

cat > "$WORK_DIR/build.sh" << 'EOF_BUILD'
#!/usr/bin/env sh
set -eu
exit 0
EOF_BUILD
chmod +x "$WORK_DIR/build.sh"

(
  cd "$WORK_DIR"
  HOME="$HOME_DIR" sh ./configure.sh > "$OUTPUT_FILE" << 'EOF_INPUT'
1
acme-org
ovhclaw
2026-03-26
y
y
EOF_INPUT
)

grep -Fq 'CUSTOM_OPENCLAW_IMAGE=ghcr.io/acme-org/ovhclaw:2026-03-26' "$CALLS_FILE"
grep -Fq 'CUSTOM_OPENCLAW_PUSH=1' "$CALLS_FILE"
grep -Fq 'Computed image reference:' "$OUTPUT_FILE"
grep -Fq 'ghcr.io/acme-org/ovhclaw:2026-03-26' "$OUTPUT_FILE"
grep -Fq 'docker login ghcr.io' "$OUTPUT_FILE"

echo "configure image interactive hermetic test passed"
