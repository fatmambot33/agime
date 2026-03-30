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
grep -Eq 'scp .* -r build.sh scripts templates/openclaw.json.tmpl templates/openclaw-compose.ssh-tunnel.yml.tmpl test-vps:.*/agime/' "$CALLS"
grep -Eq "ssh .*test-vps cd \".*/agime\" && chmod \\+x \\./\\*\\.sh && env OVH_ENDPOINT_API_KEY='abc123' \\./build\\.sh" "$CALLS"

# OPENCLAW_ACCESS_MODE from SYNC_LOCAL_ENV_FILE should drive template selection
# even when SYNC_CONFIG_FILE is not used.
CONF_PUBLIC="$TMP_DIR/public-sync.env"
cat > "$CONF_PUBLIC" << EOF3
OVH_ENDPOINT_API_KEY=abc123
OPENCLAW_ACCESS_MODE=public
TRAEFIK_ACME_EMAIL=ops@example.com
OPENCLAW_DOMAIN=openclaw.example.com
EOF3

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE=/dev/null \
    REMOTE_HOST=test-vps \
    SYNC_LOCAL_ENV_FILE="$CONF_PUBLIC" \
    sh ./sync.sh
)

grep -Eq 'scp .* -r build.sh scripts templates/openclaw.json.tmpl templates/openclaw-compose.public.yml.tmpl templates/traefik-compose.yml.tmpl test-vps:.*/agime/' "$CALLS"
grep -Eq "ssh .*test-vps cd \".*/agime\" && chmod \\+x \\./\\*\\.sh && env OPENCLAW_ACCESS_MODE='public' OVH_ENDPOINT_API_KEY='abc123' TRAEFIK_ACME_EMAIL='ops@example.com' OPENCLAW_DOMAIN='openclaw.example.com' \\./build\\.sh" "$CALLS"

echo 'sync_hermetic: ok'
