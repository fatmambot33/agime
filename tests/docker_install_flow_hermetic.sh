#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# shellcheck source=scripts/build_lib.sh
. "$REPO_DIR/scripts/build_lib.sh"
# shellcheck source=scripts/build_steps.sh
. "$REPO_DIR/scripts/build_steps.sh"

mkdir -p "$TMP_DIR/bin"

cat > "$TMP_DIR/bin/git" << 'EOF2'
#!/usr/bin/env sh
exit 0
EOF2
chmod +x "$TMP_DIR/bin/git"

# Missing docker should auto-install and then pass checks.
DRY_RUN=0
POST_BUILD_TEST=0
SKIP_DOCKER_GROUP_SETUP=1
TEST_DOCKER_STUB="$TMP_DIR/docker-stub"
cat > "$TEST_DOCKER_STUB" << 'EOF2'
#!/usr/bin/env sh
if [ "${1:-}" = "compose" ] && [ "${2:-}" = "version" ]; then
  exit 0
fi
if [ "${1:-}" = "ps" ]; then
  exit 0
fi
exit 0
EOF2
chmod +x "$TEST_DOCKER_STUB"

install_docker_on_host() {
  log "Docker is missing; installing Docker and docker compose on host"
  ln -sf "$TEST_DOCKER_STUB" "$TMP_DIR/bin/docker"
}

PATH="$TMP_DIR/bin:/bin"
check_docker_access > "$TMP_DIR/check.out" 2>&1
/bin/grep -q 'installing Docker and docker compose on host' "$TMP_DIR/check.out"
[ -x "$TMP_DIR/bin/docker" ]

echo 'docker_install_flow_hermetic: ok'
