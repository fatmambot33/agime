#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

run_prepare() {
  mode=$1
  fixture="$TMP_DIR/$mode"
  bin_dir="$fixture/bin"
  calls_file="$fixture/calls.log"
  openclaw_dir="$fixture/openclaw"
  custom_config_dir="$fixture/custom-config"
  workspace_dir="$fixture/custom-workspace"

  mkdir -p "$bin_dir" "$fixture"
  : > "$calls_file"

  cat > "$bin_dir/git" << EOF
#!/usr/bin/env sh
set -eu
if [ "\$1" = "clone" ]; then
  mkdir -p "\$3/.git"
  exit 0
fi
echo "unexpected git args: \$*" >&2
exit 1
EOF

  cat > "$bin_dir/chown" << EOF
#!/usr/bin/env sh
printf 'chown %s\n' "\$*" >> "$calls_file"
exit 0
EOF

  if [ "$mode" = "nonroot" ]; then
    cat > "$bin_dir/id" << 'EOF'
#!/usr/bin/env sh
if [ "$1" = "-u" ]; then
  printf '1000\n'
  exit 0
fi
if [ "$1" = "-un" ]; then
  printf 'tester\n'
  exit 0
fi
exec /usr/bin/id "$@"
EOF

    cat > "$bin_dir/sudo" << EOF
#!/usr/bin/env sh
printf 'sudo %s\n' "\$*" >> "$calls_file"
"\$@"
EOF
    chmod +x "$bin_dir/sudo"
  else
    cat > "$bin_dir/id" << 'EOF'
#!/usr/bin/env sh
if [ "$1" = "-u" ]; then
  printf '0\n'
  exit 0
fi
if [ "$1" = "-un" ]; then
  printf 'root\n'
  exit 0
fi
exec /usr/bin/id "$@"
EOF
  fi

  chmod +x "$bin_dir/git" "$bin_dir/chown" "$bin_dir/id"

  (
    cd "$REPO_DIR"
    PATH="$bin_dir:$PATH"
    SCRIPT_DIR="$REPO_DIR"
    DRY_RUN=0
    OPENCLAW_DIR="$openclaw_dir"
    OPENCLAW_REPO="https://example.invalid/openclaw.git"
    OPENCLAW_CONFIG_DIR="$custom_config_dir"
    OPENCLAW_WORKSPACE_DIR="$workspace_dir"
    OPENCLAW_USER="tester"
    . "$REPO_DIR/scripts/build_lib.sh"
    . "$REPO_DIR/scripts/build_steps.sh"
    prepare_openclaw_repo
  )

  [ -d "$custom_config_dir" ]
  [ -d "$workspace_dir" ]

  if [ "$mode" = "nonroot" ]; then
    grep -Fq "sudo chown -R tester:tester $openclaw_dir $custom_config_dir" "$calls_file"
  else
    grep -Fq "chown -R tester:tester $openclaw_dir $custom_config_dir" "$calls_file"
    if grep -q '^sudo ' "$calls_file"; then
      echo "root flow should not invoke sudo" >&2
      exit 1
    fi
  fi
}

run_prepare nonroot
run_prepare root

echo "ownership and config-dir prep hermetic test passed"
