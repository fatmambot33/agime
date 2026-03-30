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

CONF="$TMP_DIR/legacy.conf"
cat > "$CONF" << EOF2
REMOTE_HOST=test-vps
REMOTE_DIR=~/agime
SYNC_REMOTE_ENTRYPOINT=configure.sh
OVH_ENDPOINT_API_KEY=test
OPENCLAW_ACTION=install
SYNC_REMOTE_CONFIG_PRIORITY=1
EOF2

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" SYNC_CONFIG_FILE="$CONF" sh ./sync.sh > "$TMP_DIR/stdout.log" 2> "$TMP_DIR/stderr.log"
)

grep -q 'deprecated; using build.sh' "$TMP_DIR/stderr.log"
grep -q 'OPENCLAW_ACTION is deprecated and ignored' "$TMP_DIR/stderr.log"
grep -q 'SYNC_REMOTE_CONFIG_PRIORITY is deprecated and ignored' "$TMP_DIR/stderr.log"
grep -Eq 'ssh .*\./build\.sh' "$CALLS"

echo 'sync_compat_shims_hermetic: ok'
