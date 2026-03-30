#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
mkdir -p "$BIN_DIR"
CALLS="$TMP_DIR/calls.log"
: > "$CALLS"

cat > "$BIN_DIR/ssh" << 'EOS'
#!/usr/bin/env sh
printf 'ssh %s\n' "$*" >> "__CALLS__"
exit 0
EOS
cat > "$BIN_DIR/scp" << 'EOS'
#!/usr/bin/env sh
printf 'scp %s\n' "$*" >> "__CALLS__"
exit 0
EOS
sed -i "s#__CALLS__#$CALLS#g" "$BIN_DIR/ssh" "$BIN_DIR/scp"
chmod +x "$BIN_DIR/ssh" "$BIN_DIR/scp"

CONF="$TMP_DIR/sync.conf"
cat > "$CONF" << EOF2
REMOTE_HOST=test-vps
REMOTE_DIR=~/agime
OVH_ENDPOINT_API_KEY=abc123
EOF2

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" SYNC_CONFIG_FILE="$CONF" sh ./sync.sh
)

grep -Eq 'ssh .*test-vps mkdir -p ".*/agime"' "$CALLS"
grep -Eq 'scp .* -r build.sh sync.sh setup.sh backup.sh restore.sh update.sh scripts templates docs README.md Makefile test-vps:.*/agime/' "$CALLS"
grep -Eq "scp .* $CONF test-vps:.*/agime/sync.conf" "$CALLS"
grep -Eq 'ssh .*test-vps cd ".*/agime" && chmod \+x \./\*\.sh && set -a && \. '\''\./sync\.conf'\'' && set \+a && \./build\.sh' "$CALLS"

echo 'sync_hermetic: ok'
