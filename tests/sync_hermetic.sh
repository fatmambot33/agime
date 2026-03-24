#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
mkdir -p "$BIN_DIR"
CALLS_FILE="$TMP_DIR/calls.log"
: > "$CALLS_FILE"

cat > "$BIN_DIR/ssh" << EOF
#!/usr/bin/env sh
printf 'ssh %s\n' "\$*" >> "$CALLS_FILE"
exit 0
EOF

cat > "$BIN_DIR/scp" << EOF
#!/usr/bin/env sh
printf 'scp %s\n' "\$*" >> "$CALLS_FILE"
exit 0
EOF

chmod +x "$BIN_DIR/ssh" "$BIN_DIR/scp"

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    REMOTE_HOST=test-host \
    REMOTE_DIR=/tmp/test-agime \
    sh ./sync.sh
)

grep -Fq "ssh test-host mkdir -p '/tmp/test-agime'" "$CALLS_FILE"
grep -Fq "scp -r build-interactive.sh build.sh backup.sh restore.sh scripts templates test-host:/tmp/test-agime/" "$CALLS_FILE"
grep -Fq "ssh -t test-host cd '/tmp/test-agime' && chmod +x ./*.sh && ./build-interactive.sh" "$CALLS_FILE"

echo "sync.sh hermetic test passed"
