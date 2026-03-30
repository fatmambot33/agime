#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# shellcheck source=scripts/build_lib.sh
. "$REPO_DIR/scripts/build_lib.sh"
# shellcheck source=scripts/build_steps.sh
. "$REPO_DIR/scripts/build_steps.sh"

write_wizard() {
  wizard_dir=$1
  cat > "$wizard_dir/docker-setup.sh" << 'EOF2'
#!/bin/sh
set -eu
printf 'OPENCLAW_GATEWAY_TOKEN=wizard-token\n' > .env
printf 'wizard-ran\n' > .wizard-ran
EOF2
  chmod +x "$wizard_dir/docker-setup.sh"
}

# First run (ssh-tunnel): bootstrap should create .env without wizard.
OPENCLAW_DIR="$TMP_DIR/ssh"
OPENCLAW_CONFIG_DIR="$TMP_DIR/ssh-config"
OPENCLAW_WORKSPACE_DIR="$TMP_DIR/ssh-workspace"
OPENCLAW_IMAGE="openclaw:test"
OPENCLAW_GATEWAY_BIND="lan"
OPENCLAW_TOKEN="token-ssh"
DRY_RUN=0
SKIP_OPENCLAW_WIZARD=0
mkdir -p "$OPENCLAW_DIR"
write_wizard "$OPENCLAW_DIR"
run_openclaw_wizard_if_needed

[ -f "$OPENCLAW_DIR/.env" ]
grep -q '^OPENCLAW_GATEWAY_TOKEN=token-ssh$' "$OPENCLAW_DIR/.env"
grep -q '^OPENCLAW_CONFIG_DIR='"$OPENCLAW_CONFIG_DIR"'$' "$OPENCLAW_DIR/.env"
[ ! -f "$OPENCLAW_DIR/.wizard-ran" ]

# First run (public): same bootstrap path should apply.
OPENCLAW_DIR="$TMP_DIR/public"
OPENCLAW_CONFIG_DIR="$TMP_DIR/public-config"
OPENCLAW_WORKSPACE_DIR="$TMP_DIR/public-workspace"
OPENCLAW_IMAGE="openclaw:test"
OPENCLAW_GATEWAY_BIND="lan"
OPENCLAW_TOKEN="token-public"
DRY_RUN=0
SKIP_OPENCLAW_WIZARD=0
mkdir -p "$OPENCLAW_DIR"
write_wizard "$OPENCLAW_DIR"
run_openclaw_wizard_if_needed

[ -f "$OPENCLAW_DIR/.env" ]
grep -q '^OPENCLAW_GATEWAY_TOKEN=token-public$' "$OPENCLAW_DIR/.env"
[ ! -f "$OPENCLAW_DIR/.wizard-ran" ]

# Existing .env: should skip bootstrap and wizard.
OPENCLAW_DIR="$TMP_DIR/existing"
OPENCLAW_CONFIG_DIR="$TMP_DIR/existing-config"
OPENCLAW_WORKSPACE_DIR="$TMP_DIR/existing-workspace"
OPENCLAW_IMAGE="openclaw:test"
OPENCLAW_GATEWAY_BIND="lan"
OPENCLAW_TOKEN="token-new"
DRY_RUN=0
SKIP_OPENCLAW_WIZARD=0
mkdir -p "$OPENCLAW_DIR"
write_wizard "$OPENCLAW_DIR"
printf 'OPENCLAW_GATEWAY_TOKEN=existing-token\n' > "$OPENCLAW_DIR/.env"
run_openclaw_wizard_if_needed
grep -q '^OPENCLAW_GATEWAY_TOKEN=existing-token$' "$OPENCLAW_DIR/.env"
[ ! -f "$OPENCLAW_DIR/.wizard-ran" ]

# Missing token generation tools: should fall back to wizard when allowed.
OPENCLAW_DIR="$TMP_DIR/fallback"
OPENCLAW_CONFIG_DIR="$TMP_DIR/fallback-config"
OPENCLAW_WORKSPACE_DIR="$TMP_DIR/fallback-workspace"
OPENCLAW_IMAGE="openclaw:test"
OPENCLAW_GATEWAY_BIND="lan"
unset OPENCLAW_TOKEN || true
DRY_RUN=0
SKIP_OPENCLAW_WIZARD=0
mkdir -p "$OPENCLAW_DIR"
write_wizard "$OPENCLAW_DIR"
(
  PATH='/path/that/does/not/exist'
  run_openclaw_wizard_if_needed
)
grep -q '^OPENCLAW_GATEWAY_TOKEN=wizard-token$' "$OPENCLAW_DIR/.env"
[ -f "$OPENCLAW_DIR/.wizard-ran" ]

# Missing token generation tools + SKIP_OPENCLAW_WIZARD=1: fail predictably.
OPENCLAW_DIR="$TMP_DIR/fail"
OPENCLAW_CONFIG_DIR="$TMP_DIR/fail-config"
OPENCLAW_WORKSPACE_DIR="$TMP_DIR/fail-workspace"
OPENCLAW_IMAGE="openclaw:test"
OPENCLAW_GATEWAY_BIND="lan"
unset OPENCLAW_TOKEN || true
DRY_RUN=0
SKIP_OPENCLAW_WIZARD=1
mkdir -p "$OPENCLAW_DIR"
write_wizard "$OPENCLAW_DIR"
set +e
(
  PATH='/path/that/does/not/exist'
  run_openclaw_wizard_if_needed
) > "$TMP_DIR/fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'SKIP_OPENCLAW_WIZARD=1' "$TMP_DIR/fail.out"

echo 'build_first_run_bootstrap_hermetic: ok'
