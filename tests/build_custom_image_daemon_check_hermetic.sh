#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
mkdir -p "$BIN_DIR"
OUTPUT_FILE="$TMP_DIR/output.log"
ERROR_FILE="$TMP_DIR/error.log"
BUILD_MARKER="$TMP_DIR/build.marker"

cat > "$BIN_DIR/docker" << EOF_DOCKER
#!/usr/bin/env sh
set -eu

cmd=
if [ "\$#" -gt 0 ]; then
  cmd=\$1
fi

case "\$cmd" in
  info)
    printf '%s\n' 'failed to connect to the docker API at unix:///var/run/docker.sock: connect: no such file or directory' >&2
    exit 1
    ;;
  build)
    printf 'build-called\n' >> "$BUILD_MARKER"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF_DOCKER
chmod +x "$BIN_DIR/docker"

set +e
PATH="$BIN_DIR:$PATH" \
  CUSTOM_OPENCLAW_IMAGE='ghcr.io/acme-org/openclaw-agent-tools:2026-03-26' \
  sh "$REPO_DIR/scripts/build_custom_image.sh" > "$OUTPUT_FILE" 2> "$ERROR_FILE"
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  echo "expected build_custom_image.sh to fail when docker daemon is unreachable" >&2
  exit 1
fi

if [ -f "$BUILD_MARKER" ]; then
  echo "docker build must not run when daemon check fails" >&2
  exit 1
fi

grep -Fq 'docker is installed but the Docker daemon/API is unreachable' "$ERROR_FILE"
grep -Fq 'docker info error:' "$ERROR_FILE"

echo "build_custom_image daemon check hermetic test passed"
