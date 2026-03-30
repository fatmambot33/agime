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
case "\$*" in
  *" test -f "*)
    if [ "\${MOCK_REMOTE_ENV_EXISTS:-0}" = "1" ]; then
      exit 0
    fi
    exit 1
    ;;
esac
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
          [ -f "\$last_arg" ] || : > "\$last_arg"
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
  AUTO_CONFIG_FILE="$TMP_DIR/auto-sync.conf"
  cat > "$AUTO_CONFIG_FILE" << EOF
REMOTE_HOST=test-host
REMOTE_DIR=/tmp/test-agime
EOF
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$AUTO_CONFIG_FILE" \
    sh ./sync.sh > "$TMP_DIR/default.stdout" 2>&1
)

grep -Fq "sync.sh preflight warning:" "$TMP_DIR/default.stdout"
grep -Fq "requires OVH_ENDPOINT_API_KEY" "$TMP_DIR/default.stdout"
grep -Eq "ssh .*test-host mkdir -p \"/tmp/test-agime\"" "$CALLS_FILE"
grep -Eq "scp .* -r build.sh backup.sh update.sh image.sh restore.sh scripts templates docs README.md $TMP_DIR/auto-sync\\.conf test-host:/tmp/test-agime/" "$CALLS_FILE"
if grep -Eq "scp .* $TMP_DIR/auto-sync\\.conf test-host:/tmp/test-agime/auto-sync\\.conf" "$CALLS_FILE"; then
  echo "expected single upload path for auto-sync.conf, but found duplicate explicit env upload" >&2
  exit 1
fi
grep -Eq "ssh .* test-host cd \"/tmp/test-agime\" && chmod \+x \./\*\.sh && set -a && \. '\./auto-sync\.conf' && set \+a && \./build.sh" "$CALLS_FILE"
grep -Eq "ssh .* -O exit test-host" "$CALLS_FILE"

CONFIG_WITH_KEY="$TMP_DIR/config-with-key.conf"
cat > "$CONFIG_WITH_KEY" << EOF
REMOTE_HOST=key-host
REMOTE_DIR=/tmp/key-agime
OVH_ENDPOINT_API_KEY=from-config
EOF

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$CONFIG_WITH_KEY" \
    sh ./sync.sh > "$TMP_DIR/with-key.stdout" 2>&1
)

if grep -Fq "sync.sh preflight warning:" "$TMP_DIR/with-key.stdout"; then
  echo "did not expect preflight warning when OVH_ENDPOINT_API_KEY is set in sync config" >&2
  exit 1
fi

(
  cd "$REPO_DIR"
  AUTO_CONFIG_FILE="$TMP_DIR/auto-sync.conf"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$AUTO_CONFIG_FILE" \
    OPENCLAW_ACTION=install \
    sh ./sync.sh
)

grep -Eq "ssh .* test-host cd \"/tmp/test-agime\" && chmod \+x \./\*\.sh && set -a && \. '\./auto-sync\.conf' && set \+a && \./build.sh" "$CALLS_FILE"

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
grep -Eq "ssh .*config-host mkdir -p \"/tmp/config-agime\"" "$CALLS_FILE"
grep -Eq "scp .* $CONFIG_FILE config-host:/tmp/config-agime/" "$CALLS_FILE"
grep -Eq "scp .* $TMP_DIR/mirrored\\.env config-host:/tmp/config-agime/\\.sync-build\\.env" "$CALLS_FILE"
grep -Eq "ssh .* config-host cd \"/tmp/config-agime\" && chmod \+x \./\*\.sh && set -a && \. '\./\.sync-build\.env' && set \+a && \./build.sh" "$CALLS_FILE"
grep -Eq "scp .* config-host:/tmp/config-agime/\.sync-build\.env $TMP_DIR/mirrored\.env" "$CALLS_FILE"

REMOTE_PRIORITY_CONFIG="$TMP_DIR/remote-priority.conf"
cat > "$REMOTE_PRIORITY_CONFIG" << EOF
REMOTE_HOST=remote-priority-host
REMOTE_DIR=/tmp/remote-priority-agime
OVH_ENDPOINT_API_KEY=local-should-not-win
EOF

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    MOCK_REMOTE_ENV_EXISTS=1 \
    SYNC_CONFIG_FILE="$REMOTE_PRIORITY_CONFIG" \
    sh ./sync.sh
)

grep -Eq "scp .* remote-priority-host:/tmp/remote-priority-agime/remote-priority\\.conf $REMOTE_PRIORITY_CONFIG" "$CALLS_FILE"
if grep -Eq "scp .* $REMOTE_PRIORITY_CONFIG remote-priority-host:/tmp/remote-priority-agime/" "$CALLS_FILE"; then
  echo "did not expect local config upload when remote env file already exists" >&2
  exit 1
fi

PORTABLE_DIR="$TMP_DIR/portable"
mkdir -p "$PORTABLE_DIR"
cp "$REPO_DIR/sync.sh" "$PORTABLE_DIR/sync.sh"
cat > "$PORTABLE_DIR/sync.conf.example" << EOF
OPENCLAW_DIR=$TMP_DIR/home/openclaw
OPENCLAW_CONFIG_DIR=$TMP_DIR/home/.openclaw
OPENCLAW_WORKSPACE_DIR=$TMP_DIR/home/.openclaw/workspace
TRAEFIK_DIR=$TMP_DIR/home/docker/traefik
OPENCLAW_JSON_BACKUP_DIR=$TMP_DIR/home/openclaw-backups
EOF
chmod +x "$PORTABLE_DIR/sync.sh"

(
  cd "$PORTABLE_DIR"
  HOME="$TMP_DIR/home" \
    PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$PORTABLE_DIR/sync.conf" \
    REMOTE_HOST=portable-host \
    REMOTE_DIR=/tmp/portable-agime \
    sh ./sync.sh > "$TMP_DIR/portable.stdout" 2>&1
)

grep -Fq "sync.sh: local config ready at $PORTABLE_DIR/sync.conf" "$TMP_DIR/portable.stdout"
grep -Fq "OPENCLAW_DIR=~/openclaw" "$PORTABLE_DIR/sync.conf"
grep -Fq "OPENCLAW_CONFIG_DIR=~/.openclaw" "$PORTABLE_DIR/sync.conf"
grep -Fq "OPENCLAW_WORKSPACE_DIR=~/.openclaw/workspace" "$PORTABLE_DIR/sync.conf"
grep -Fq "TRAEFIK_DIR=~/docker/traefik" "$PORTABLE_DIR/sync.conf"
grep -Fq "OPENCLAW_JSON_BACKUP_DIR=~/openclaw-backups" "$PORTABLE_DIR/sync.conf"
grep -Eq "scp .* -r build.sh backup.sh update.sh image.sh restore.sh scripts templates docs README.md $PORTABLE_DIR/sync\\.conf portable-host:/tmp/portable-agime/" "$CALLS_FILE"

BOOTSTRAP_DIR="$TMP_DIR/bootstrap"
mkdir -p "$BOOTSTRAP_DIR"
cp "$REPO_DIR/sync.sh" "$BOOTSTRAP_DIR/sync.sh"
cat > "$BOOTSTRAP_DIR/sync.conf.example" << EOF
REMOTE_HOST=user@example-vps
REMOTE_DIR=/tmp/agime
EOF
chmod +x "$BOOTSTRAP_DIR/sync.sh"

(
  cd "$BOOTSTRAP_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$BOOTSTRAP_DIR/generated.conf" \
    REMOTE_HOST=runtime-host \
    REMOTE_DIR=/tmp/runtime-agime \
    sh ./sync.sh > "$TMP_DIR/bootstrap.stdout" 2>&1
)

grep -Fq "REMOTE_HOST=runtime-host" "$BOOTSTRAP_DIR/generated.conf"
grep -Fq "REMOTE_DIR=/tmp/runtime-agime" "$BOOTSTRAP_DIR/generated.conf"
grep -Eq "ssh .*runtime-host mkdir -p \"/tmp/runtime-agime\"" "$CALLS_FILE"

EXPANDED_HOME_DIR="$TMP_DIR/expanded-home"
mkdir -p "$EXPANDED_HOME_DIR"
EXPANDED_CONFIG="$TMP_DIR/expanded-home.conf"
cat > "$EXPANDED_CONFIG" << EOF
REMOTE_HOST=expanded-host
REMOTE_DIR=$EXPANDED_HOME_DIR/agime
EOF

(
  cd "$REPO_DIR"
  HOME="$EXPANDED_HOME_DIR" \
    PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$EXPANDED_CONFIG" \
    sh ./sync.sh > "$TMP_DIR/expanded-home.stdout" 2>&1
)

grep -Eq 'ssh .*expanded-host mkdir -p "\$HOME/agime"' "$CALLS_FILE"
grep -Eq "scp .* -r build.sh backup.sh update.sh image.sh restore.sh scripts templates docs README.md $EXPANDED_CONFIG expanded-host:~/agime/" "$CALLS_FILE"

EXPANDED_BOOTSTRAP_DIR="$TMP_DIR/bootstrap-expanded"
mkdir -p "$EXPANDED_BOOTSTRAP_DIR"
cp "$REPO_DIR/sync.sh" "$EXPANDED_BOOTSTRAP_DIR/sync.sh"
cat > "$EXPANDED_BOOTSTRAP_DIR/sync.conf.example" << EOF
REMOTE_HOST=user@example-vps
REMOTE_DIR=/tmp/agime
EOF
chmod +x "$EXPANDED_BOOTSTRAP_DIR/sync.sh"

(
  cd "$EXPANDED_BOOTSTRAP_DIR"
  HOME="$EXPANDED_HOME_DIR" \
    PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$EXPANDED_BOOTSTRAP_DIR/generated.conf" \
    REMOTE_HOST=runtime-expanded-host \
    REMOTE_DIR="$EXPANDED_HOME_DIR/agime" \
    sh ./sync.sh > "$TMP_DIR/bootstrap-expanded.stdout" 2>&1
)

grep -Fq "REMOTE_DIR=~/agime" "$EXPANDED_BOOTSTRAP_DIR/generated.conf"
grep -Eq 'ssh .*runtime-expanded-host mkdir -p "\$HOME/agime"' "$CALLS_FILE"

MAC_PATH_CONFIG="$TMP_DIR/mac-path.conf"
cat > "$MAC_PATH_CONFIG" << EOF
REMOTE_HOST=ubuntu@vps-host
REMOTE_DIR=/Users/pfourcat/agime
EOF

set +e
(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$MAC_PATH_CONFIG" \
    sh ./sync.sh > "$TMP_DIR/mac-path.stdout" 2>&1
)
MAC_PATH_STATUS=$?
set -e

[ "$MAC_PATH_STATUS" -ne 0 ]
grep -Fq "sync.sh preflight error:" "$TMP_DIR/mac-path.stdout"
grep -Fq "REMOTE_DIR=/Users/pfourcat/agime looks like a local macOS home path." "$TMP_DIR/mac-path.stdout"

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_ALLOW_ABSOLUTE_REMOTE_DIR=1 \
    SYNC_CONFIG_FILE="$MAC_PATH_CONFIG" \
    sh ./sync.sh > "$TMP_DIR/mac-path-allowed.stdout" 2>&1
)

grep -Eq "ssh .*ubuntu@vps-host mkdir -p \"/Users/pfourcat/agime\"" "$CALLS_FILE"

cat > "$MAC_PATH_CONFIG" << EOF
REMOTE_HOST=ubuntu@[::1]
REMOTE_DIR=/Users/pfourcat/agime
EOF

(
  cd "$REPO_DIR"
  PATH="$BIN_DIR:$PATH" \
    SYNC_CONFIG_FILE="$MAC_PATH_CONFIG" \
    sh ./sync.sh > "$TMP_DIR/mac-path-ipv6-loopback.stdout" 2>&1
)

if grep -Fq "sync.sh preflight error:" "$TMP_DIR/mac-path-ipv6-loopback.stdout"; then
  echo "did not expect preflight error for bracketed IPv6 loopback host" >&2
  exit 1
fi
grep -Eq "ssh .*ubuntu@\\[::1\\] mkdir -p \"/Users/pfourcat/agime\"" "$CALLS_FILE"

echo "sync.sh hermetic test passed"
