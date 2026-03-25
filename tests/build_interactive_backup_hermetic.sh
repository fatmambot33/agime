#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

WORK_DIR="$TMP_DIR/work"
HOME_DIR="$TMP_DIR/home"
mkdir -p "$WORK_DIR" "$HOME_DIR"

cp "$REPO_DIR/build-interactive.sh" "$WORK_DIR/build-interactive.sh"
chmod +x "$WORK_DIR/build-interactive.sh"

CALLS_FILE="$TMP_DIR/calls.log"
: > "$CALLS_FILE"

cat > "$WORK_DIR/build.sh" << EOF_BUILD
#!/usr/bin/env sh
set -eu
printf 'RUN_BUILD\n' >> "$CALLS_FILE"
EOF_BUILD

# shellcheck disable=SC2016
cat > "$WORK_DIR/backup.sh" << 'EOF_BACKUP_REAL'
#!/usr/bin/env sh
set -eu
printf 'RUN_BACKUP INCLUDE_TRAEFIK=%s INCLUDE_OPENCLAW_REPO=%s EXTRA_BACKUP_PATHS=%s BACKUP_OUTPUT=%s OPENCLAW_DIR=%s OPENCLAW_CONFIG_DIR=%s\n' \
  "$INCLUDE_TRAEFIK" "$INCLUDE_OPENCLAW_REPO" "$EXTRA_BACKUP_PATHS" "$BACKUP_OUTPUT" "$OPENCLAW_DIR" "$OPENCLAW_CONFIG_DIR" >> "__CALLS_FILE__"
EOF_BACKUP_REAL

sed -i "s|__CALLS_FILE__|$CALLS_FILE|g" "$WORK_DIR/backup.sh"
chmod +x "$WORK_DIR/build.sh" "$WORK_DIR/backup.sh"

(
  cd "$WORK_DIR"
  HOME="$HOME_DIR" sh ./build-interactive.sh << 'EOF_INPUT'
1
ssh-tunnel
api-key-123





0
0
0
0
0
y


relative-backup.tgz
y
EOF_INPUT
)

grep -Fq 'RUN_BACKUP' "$CALLS_FILE"
grep -Fq 'BACKUP_OUTPUT=relative-backup.tgz' "$CALLS_FILE"
grep -Fq "OPENCLAW_DIR=$HOME_DIR/openclaw" "$CALLS_FILE"
grep -Fq 'RUN_BUILD' "$CALLS_FILE"

first_line=$(sed -n '1p' "$CALLS_FILE")
second_line=$(sed -n '2p' "$CALLS_FILE")
[ "$first_line" != "$second_line" ]
printf '%s\n' "$first_line" | grep -Fq 'RUN_BACKUP'
printf '%s\n' "$second_line" | grep -Fq 'RUN_BUILD'

echo "build_interactive_backup_hermetic test passed"
