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
last_arg=
has_remote=0
for arg in "\$@"; do
  last_arg=\$arg
  case "\$arg" in
    *:*) has_remote=1 ;;
  esac
done
if [ "\$has_remote" = "1" ]; then
  case "\$last_arg" in
    *:*) ;;
    *)
      case "\$last_arg" in
        /* | ./* | ../* | "$TMP_DIR"/*)
          : > "\$last_arg"
          ;;
      esac
      ;;
  esac
fi
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

grep -Eq "ssh .*test-host mkdir -p '/tmp/test-agime'" "$CALLS_FILE"
grep -Eq "scp .* -r build-interactive.sh build.sh backup.sh update.sh add_tool.sh restore.sh sync.sh scripts templates docs README.md test-host:/tmp/test-agime/" "$CALLS_FILE"
grep -Eq "ssh .* -t test-host cd '/tmp/test-agime' && chmod \+x \./\*\.sh && OPENCLAW_EXPORT_ENV_FILE='' \./build-interactive.sh" "$CALLS_FILE"
grep -Eq "ssh .* -O exit test-host" "$CALLS_FILE"

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    REMOTE_HOST=test-host \
    REMOTE_DIR=/tmp/test-agime \
    OPENCLAW_ACTION=security \
    sh ./sync.sh
)

grep -Eq "ssh .* -t test-host cd '/tmp/test-agime' && chmod \+x \./\*\.sh && OPENCLAW_ACTION='security' OPENCLAW_EXPORT_ENV_FILE='' \./build-interactive.sh" "$CALLS_FILE"

CONFIG_FILE="$TMP_DIR/sync.conf"
cat > "$CONFIG_FILE" << EOF
REMOTE_HOST=config-host
REMOTE_DIR=/tmp/config-agime
SYNC_REMOTE_ENTRYPOINT=build.sh
SYNC_REMOTE_ENV_FILE=.sync-build.env
SYNC_MIRROR_ENV_FILE=1
SYNC_LOCAL_ENV_FILE=$TMP_DIR/mirrored.env
SYNC_PRINT_CONFIG=1
EOF
printf 'OVH_ENDPOINT_API_KEY=test-key\n' > "$TMP_DIR/mirrored.env"

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$CONFIG_FILE" \
    sh ./sync.sh > "$TMP_DIR/config.stdout"
)

grep -Fq "sync.sh effective config:" "$TMP_DIR/config.stdout"
grep -Fq "REMOTE_HOST=config-host" "$TMP_DIR/config.stdout"
grep -Eq "ssh .*config-host mkdir -p '/tmp/config-agime'" "$CALLS_FILE"
grep -Eq "scp .* $CONFIG_FILE config-host:/tmp/config-agime/" "$CALLS_FILE"
grep -Eq "scp .* $TMP_DIR/mirrored\\.env config-host:/tmp/config-agime/\\.sync-build\\.env" "$CALLS_FILE"
grep -Eq "ssh .* config-host cd '/tmp/config-agime' && chmod \+x \./\*\.sh && \. '\./\.sync-build\.env' && \./build.sh" "$CALLS_FILE"
grep -Eq "scp .* config-host:/tmp/config-agime/\.sync-build\.env $TMP_DIR/mirrored\.env" "$CALLS_FILE"

echo "sync.sh hermetic test passed"
