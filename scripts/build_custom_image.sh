#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

CUSTOM_OPENCLAW_IMAGE=${CUSTOM_OPENCLAW_IMAGE:-""}
CUSTOM_OPENCLAW_BASE_IMAGE=${CUSTOM_OPENCLAW_BASE_IMAGE:-"ghcr.io/openclaw/openclaw:latest"}
CUSTOM_OPENCLAW_DOCKERFILE_TEMPLATE=${CUSTOM_OPENCLAW_DOCKERFILE_TEMPLATE:-"$SCRIPT_DIR/templates/openclaw-custom-image.Dockerfile.tmpl"}
CUSTOM_OPENCLAW_PUSH=${CUSTOM_OPENCLAW_PUSH:-"0"}
CUSTOM_OPENCLAW_BROWSER_DEPS=${CUSTOM_OPENCLAW_BROWSER_DEPS:-"0"}
SIGNAL_CLI_VERSION=${SIGNAL_CLI_VERSION:-"0.13.18"}
OPENCODE_NPM_PACKAGE=${OPENCODE_NPM_PACKAGE:-"@opencode-ai/cli"}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

validate_custom_image_reference() {
  image_ref=$1

  case "$image_ref" in
    ghcr.io/*/*:*)
      image_without_registry=${image_ref#ghcr.io/}
      image_repo=${image_without_registry%:*}
      ;;
    *)
      fail "CUSTOM_OPENCLAW_IMAGE must follow ghcr.io/<owner>/<image-name>:<tag> (got: $image_ref)"
      ;;
  esac

  case "$image_repo" in
    *[A-Z]*)
      fail "CUSTOM_OPENCLAW_IMAGE owner/image must be lowercase for GHCR (got: $image_ref)"
      ;;
  esac
}

require_command() {
  command_name=$1
  if ! command -v "$command_name" > /dev/null 2>&1; then
    fail "Required command not found: $command_name. Install Docker Engine + docker compose plugin, then rerun."
  fi
}

run_with_optional_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return 0
  fi

  if command -v sudo > /dev/null 2>&1; then
    sudo "$@"
    return 0
  fi

  fail "Root privileges are required for Docker install. Run as root or install 'sudo'."
}

docker_install_supported_platform() {
  [ -f /etc/os-release ] || return 1

  os_id=$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
  os_like=$(awk -F= '/^ID_LIKE=/{gsub(/"/,"",$2); print $2}' /etc/os-release)

  case "$os_id:$os_like" in
    debian:* | ubuntu:* | *:debian* | *:ubuntu*) return 0 ;;
    *) return 1 ;;
  esac
}

install_docker_or_fail() {
  docker_install_supported_platform || fail "Automatic Docker install is currently supported on Debian/Ubuntu hosts only. Install Docker manually on this host and rerun."

  log "docker not found; attempting automatic install on Debian/Ubuntu"
  run_with_optional_sudo sh -c 'apt-get update && apt-get install -y docker.io docker-compose-v2'
}

ensure_docker_available() {
  if command -v docker > /dev/null 2>&1; then
    return 0
  fi

  install_docker_or_fail
  require_command docker
}

ensure_docker_daemon_available() {
  if daemon_error=$(docker info 2>&1 > /dev/null); then
    return 0
  fi

  fail "docker is installed but the Docker daemon/API is unreachable. Start Docker Desktop (macOS/Windows) or start the Docker service (Linux), then rerun. docker info error: $daemon_error"
}

escape_sed_replacement() {
  # Escape characters significant in sed replacement strings.
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

[ -n "$CUSTOM_OPENCLAW_IMAGE" ] || fail "CUSTOM_OPENCLAW_IMAGE is required (example: ghcr.io/<org>/openclaw-agent-tools:2026-03-26)"
[ -f "$CUSTOM_OPENCLAW_DOCKERFILE_TEMPLATE" ] || fail "Dockerfile template not found: $CUSTOM_OPENCLAW_DOCKERFILE_TEMPLATE"
validate_custom_image_reference "$CUSTOM_OPENCLAW_IMAGE"
ensure_docker_available
ensure_docker_daemon_available

if [ "$CUSTOM_OPENCLAW_BASE_IMAGE" = "ghcr.io/openclaw/openclaw:latest" ]; then
  log "Warning: using floating base tag '$CUSTOM_OPENCLAW_BASE_IMAGE'. Prefer a pinned tag/digest for production."
fi

case "$CUSTOM_OPENCLAW_PUSH" in
  0 | 1) ;;
  *) fail "CUSTOM_OPENCLAW_PUSH must be 0 or 1" ;;
esac

case "$CUSTOM_OPENCLAW_BROWSER_DEPS" in
  0 | 1) ;;
  *) fail "CUSTOM_OPENCLAW_BROWSER_DEPS must be 0 or 1" ;;
esac

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT INT HUP TERM

rendered_dockerfile="$tmp_dir/Dockerfile"
escaped_base_image=$(escape_sed_replacement "$CUSTOM_OPENCLAW_BASE_IMAGE")
sed "s/__CUSTOM_OPENCLAW_BASE_IMAGE__/${escaped_base_image}/g" "$CUSTOM_OPENCLAW_DOCKERFILE_TEMPLATE" > "$rendered_dockerfile"

log "Building custom image: $CUSTOM_OPENCLAW_IMAGE"
log "Base image: $CUSTOM_OPENCLAW_BASE_IMAGE"
log "Browser deps: $CUSTOM_OPENCLAW_BROWSER_DEPS"
log "Container CLI: docker"

docker build \
  -f "$rendered_dockerfile" \
  --build-arg "CUSTOM_OPENCLAW_BROWSER_DEPS=$CUSTOM_OPENCLAW_BROWSER_DEPS" \
  --build-arg "SIGNAL_CLI_VERSION=$SIGNAL_CLI_VERSION" \
  --build-arg "OPENCODE_NPM_PACKAGE=$OPENCODE_NPM_PACKAGE" \
  -t "$CUSTOM_OPENCLAW_IMAGE" \
  "$SCRIPT_DIR"

if [ "$CUSTOM_OPENCLAW_PUSH" = "1" ]; then
  log "Pushing image: $CUSTOM_OPENCLAW_IMAGE"
  docker push "$CUSTOM_OPENCLAW_IMAGE"
fi

log "Done. Use this image in deploys with:"
log "  OPENCLAW_IMAGE=$CUSTOM_OPENCLAW_IMAGE"
log "  SKIP_OPENCLAW_IMAGE_BUILD=1"
