#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Missing REMOTE_HOST should fail fast.
set +e
(
  cd "$REPO_DIR"
  REMOTE_HOST= sh ./sync.sh > "$TMP_DIR/no-host.out" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'REMOTE_HOST is required' "$TMP_DIR/no-host.out"

# build.sh entrypoint without OVH key should fail.
CONF_NO_KEY="$TMP_DIR/no-key.conf"
cat > "$CONF_NO_KEY" << EOF2
REMOTE_HOST=test-vps
REMOTE_DIR=~/agime
SYNC_REMOTE_ENTRYPOINT=build.sh
EOF2

set +e
(
  cd "$REPO_DIR"
  SYNC_CONFIG_FILE="$CONF_NO_KEY" sh ./sync.sh > "$TMP_DIR/no-key.out" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'OVH_ENDPOINT_API_KEY is required for build.sh remote runs' "$TMP_DIR/no-key.out"

# Non-build entrypoints should work without OVH key.
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

CONF_UPDATE="$TMP_DIR/update.conf"
cat > "$CONF_UPDATE" << EOF2
REMOTE_HOST=test-vps
REMOTE_DIR=~/agime
SYNC_REMOTE_ENTRYPOINT=update.sh
EOF2

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" SYNC_CONFIG_FILE="$CONF_UPDATE" sh ./sync.sh
)

grep -Eq 'ssh .*\./update\.sh' "$CALLS"

echo 'sync_env_edge_cases_hermetic: ok'
