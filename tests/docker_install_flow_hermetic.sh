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
PATH="$TMP_DIR/bin:$PATH"

cat > "$TMP_DIR/bin/git" << 'EOF2'
#!/usr/bin/env sh
exit 0
EOF2
chmod +x "$TMP_DIR/bin/git"

# Missing docker without install opt-in should fail.
DRY_RUN=0
POST_BUILD_TEST=0
INSTALL_DOCKER_ON_HOST=0
SKIP_DOCKER_GROUP_SETUP=1
set +e
(
  check_docker_access
) > "$TMP_DIR/missing.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'Missing required command: docker' "$TMP_DIR/missing.out"

# Install opt-in should run the install command and then pass checks.
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

INSTALL_DOCKER_ON_HOST=1
DOCKER_INSTALL_COMMAND='ln -sf "$TEST_DOCKER_STUB" "$TMP_DIR/bin/docker"'
export TEST_DOCKER_STUB TMP_DIR
check_docker_access > "$TMP_DIR/install.out" 2>&1
grep -q 'installing Docker and docker compose on host' "$TMP_DIR/install.out"
[ -x "$TMP_DIR/bin/docker" ]

echo 'docker_install_flow_hermetic: ok'
