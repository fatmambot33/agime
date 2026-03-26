#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
UPDATE_SCRIPT="$SCRIPT_DIR/update.sh"
IMAGE_SCRIPT="$SCRIPT_DIR/image.sh"
ADD_TOOL_SCRIPT="$SCRIPT_DIR/add_tool.sh"
RESTORE_SCRIPT="$SCRIPT_DIR/restore.sh"
SECURITY_SCRIPT="$SCRIPT_DIR/scripts/run_security_audit.sh"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

to_lower() {
  printf '%s' "$1" | tr 'A-Z' 'a-z'
}

normalize_ghcr_component() {
  value=$1
  normalized_value=$(to_lower "$value")
  if [ "$value" != "$normalized_value" ]; then
    printf '%s\n' "Note: normalized GHCR component '$value' to lowercase '$normalized_value'." >&2
  fi
  printf '%s' "$normalized_value"
}

ask_yes_no() {
  prompt=$1
  default=$2
  default_label=Y/n
  if [ "$default" = "n" ]; then
    default_label=y/N
  fi

  printf '%s [%s]: ' "$prompt" "$default_label"
  read answer
  answer=$(to_lower "${answer:-$default}")
  case "$answer" in
    y | yes) return 0 ;;
    n | no) return 1 ;;
    *)
      fail "Unsupported answer: $answer"
      ;;
  esac
}

ask_optional_assign() {
  var_name=$1
  prompt=$2
  default=$3
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default"
    read value
    value=${value:-$default}
  else
    printf '%s (leave blank to skip): ' "$prompt"
    read value
  fi
  eval "$var_name=\$value"
}

ask_required_with_default() {
  var_name=$1
  prompt=$2
  default=$3

  while :; do
    if [ -n "$default" ]; then
      printf '%s [%s]: ' "$prompt" "$default"
      read value
      value=${value:-$default}
    else
      printf '%s: ' "$prompt"
      read value
    fi

    if [ -n "$value" ]; then
      eval "$var_name=\$value"
      return 0
    fi

    printf 'Please enter a value for %s.\n' "$var_name"
  done
}

ask_access_mode() {
  current_mode=${OPENCLAW_ACCESS_MODE:-ssh-tunnel}
  printf 'Access mode [ssh-tunnel/public] [%s]: ' "$current_mode"
  read value
  value=${value:-$current_mode}
  case "$value" in
    ssh-tunnel | public)
      OPENCLAW_ACCESS_MODE=$value
      ;;
    *)
      fail "Unsupported access mode: $value"
      ;;
  esac
}

env_or_default() {
  var_name=$1
  fallback=$2
  eval "current_value=\${$var_name:-}"
  if [ -n "$current_value" ]; then
    printf '%s' "$current_value"
  else
    printf '%s' "$fallback"
  fi
}

choose_welcome_action() {
  if [ -n "${OPENCLAW_ACTION:-}" ]; then
    value=$(to_lower "$OPENCLAW_ACTION")
  else
    cat << 'EOF2'
Welcome to the OpenClaw toolkit.
Choose an action:
  1) Image
  2) Install
  3) Update
  4) Add Tool
  5) Backup
  6) Restore
  7) Security
EOF2
    printf 'Selection [2]: '
    read value
    value=$(to_lower "${value:-2}")
  fi
  case "$value" in
    1 | image)
      OPENCLAW_ACTION=image
      ;;
    2 | install)
      OPENCLAW_ACTION=install
      ;;
    3 | update)
      OPENCLAW_ACTION=update
      ;;
    4 | addtool | add-tool | "add tool")
      OPENCLAW_ACTION=add_tool
      ;;
    5 | backup)
      OPENCLAW_ACTION=backup
      ;;
    6 | restore)
      OPENCLAW_ACTION=restore
      ;;
    7 | security)
      OPENCLAW_ACTION=security
      ;;
    *)
      fail "Unsupported selection: $value"
      ;;
  esac
}

# read a variable with optional default
ask_var() {
  var_name=$1
  prompt=$2
  default=$3

  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default"
    read value
    value=${value:-$default}
  else
    printf '%s (leave blank to skip): ' "$prompt"
    read value
  fi

  case "$var_name" in
    TRAEFIK_ACME_EMAIL) TRAEFIK_ACME_EMAIL=$value ;;
    OPENCLAW_DOMAIN) OPENCLAW_DOMAIN=$value ;;
    OVH_ENDPOINT_API_KEY) OVH_ENDPOINT_API_KEY=$value ;;
    OPENCLAW_TOKEN) OPENCLAW_TOKEN=$value ;;
    OPENCLAW_DIR) OPENCLAW_DIR=$value ;;
    OPENCLAW_CONFIG_DIR) OPENCLAW_CONFIG_DIR=$value ;;
    OPENCLAW_WORKSPACE_DIR) OPENCLAW_WORKSPACE_DIR=$value ;;
    TRAEFIK_DIR) TRAEFIK_DIR=$value ;;
    OPENCLAW_USER) OPENCLAW_USER=$value ;;
    DRY_RUN) DRY_RUN=$value ;;
    OPENCLAW_ENABLE_SIGNAL) OPENCLAW_ENABLE_SIGNAL=$value ;;
    OPENCLAW_SIGNAL_ACCOUNT) OPENCLAW_SIGNAL_ACCOUNT=$value ;;
    OPENCLAW_SIGNAL_ALLOW_FROM) OPENCLAW_SIGNAL_ALLOW_FROM=$value ;;
    OPENCLAW_SIGNAL_CLI_PATH) OPENCLAW_SIGNAL_CLI_PATH=$value ;;
    OPENCLAW_ENABLE_GITHUB_SKILL) OPENCLAW_ENABLE_GITHUB_SKILL=$value ;;
    OPENCLAW_GH_CLI_PATH) OPENCLAW_GH_CLI_PATH=$value ;;
    OPENCLAW_ENABLE_HIMALAYA_SKILL) OPENCLAW_ENABLE_HIMALAYA_SKILL=$value ;;
    OPENCLAW_HIMALAYA_CLI_PATH) OPENCLAW_HIMALAYA_CLI_PATH=$value ;;
    OPENCLAW_HIMALAYA_REQUIRE_CONFIG) OPENCLAW_HIMALAYA_REQUIRE_CONFIG=$value ;;
    OPENCLAW_HIMALAYA_CONFIG_PATH) OPENCLAW_HIMALAYA_CONFIG_PATH=$value ;;
    OPENCLAW_ENABLE_CODING_AGENT_SKILL) OPENCLAW_ENABLE_CODING_AGENT_SKILL=$value ;;
    OPENCLAW_CODING_AGENT_BACKEND) OPENCLAW_CODING_AGENT_BACKEND=$value ;;
    *)
      fail "Unsupported variable requested: $var_name"
      ;;
  esac
}

milestone() {
  ts=$(date +'%Y-%m-%d %H:%M:%S')
  printf '%s\n' "--- [$ts] $*"
}

persist_env_file() {
  export_path=$1
  [ -n "$export_path" ] || return 0

  umask 077
  : > "$export_path"
  chmod 600 "$export_path"

  {
    printf 'OPENCLAW_ACCESS_MODE=%s\n' "$OPENCLAW_ACCESS_MODE"
    printf 'OVH_ENDPOINT_API_KEY=%s\n' "$OVH_ENDPOINT_API_KEY"
    printf 'OPENCLAW_TOKEN=%s\n' "$OPENCLAW_TOKEN"
    printf 'OPENCLAW_DIR=%s\n' "$OPENCLAW_DIR"
    printf 'OPENCLAW_CONFIG_DIR=%s\n' "$OPENCLAW_CONFIG_DIR"
    printf 'OPENCLAW_WORKSPACE_DIR=%s\n' "$OPENCLAW_WORKSPACE_DIR"
    printf 'OPENCLAW_USER=%s\n' "$OPENCLAW_USER"
    printf 'OPENCLAW_ENABLE_SIGNAL=%s\n' "$OPENCLAW_ENABLE_SIGNAL"
    printf 'OPENCLAW_ENABLE_GITHUB_SKILL=%s\n' "$OPENCLAW_ENABLE_GITHUB_SKILL"
    printf 'OPENCLAW_ENABLE_HIMALAYA_SKILL=%s\n' "$OPENCLAW_ENABLE_HIMALAYA_SKILL"
    printf 'OPENCLAW_ENABLE_CODING_AGENT_SKILL=%s\n' "$OPENCLAW_ENABLE_CODING_AGENT_SKILL"
    printf 'DRY_RUN=%s\n' "$DRY_RUN"
    printf 'OPENCLAW_ALLOWED_ORIGIN=%s\n' "${OPENCLAW_ALLOWED_ORIGIN:-}"

    if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
      printf 'TRAEFIK_ACME_EMAIL=%s\n' "$TRAEFIK_ACME_EMAIL"
      printf 'OPENCLAW_DOMAIN=%s\n' "$OPENCLAW_DOMAIN"
      printf 'TRAEFIK_DIR=%s\n' "$TRAEFIK_DIR"
    fi

    if [ "${OPENCLAW_ENABLE_SIGNAL:-0}" = "1" ]; then
      printf 'OPENCLAW_SIGNAL_ACCOUNT=%s\n' "$OPENCLAW_SIGNAL_ACCOUNT"
      printf 'OPENCLAW_SIGNAL_ALLOW_FROM=%s\n' "$OPENCLAW_SIGNAL_ALLOW_FROM"
      printf 'OPENCLAW_SIGNAL_CLI_PATH=%s\n' "$OPENCLAW_SIGNAL_CLI_PATH"
    fi

    if [ "${OPENCLAW_ENABLE_GITHUB_SKILL:-0}" = "1" ]; then
      printf 'OPENCLAW_GH_CLI_PATH=%s\n' "$OPENCLAW_GH_CLI_PATH"
    fi

    if [ "${OPENCLAW_ENABLE_HIMALAYA_SKILL:-0}" = "1" ]; then
      printf 'OPENCLAW_HIMALAYA_CLI_PATH=%s\n' "$OPENCLAW_HIMALAYA_CLI_PATH"
      printf 'OPENCLAW_HIMALAYA_REQUIRE_CONFIG=%s\n' "$OPENCLAW_HIMALAYA_REQUIRE_CONFIG"
      printf 'OPENCLAW_HIMALAYA_CONFIG_PATH=%s\n' "$OPENCLAW_HIMALAYA_CONFIG_PATH"
    fi

    if [ "${OPENCLAW_ENABLE_CODING_AGENT_SKILL:-0}" = "1" ]; then
      printf 'OPENCLAW_CODING_AGENT_BACKEND=%s\n' "$OPENCLAW_CODING_AGENT_BACKEND"
    fi
  } > "$export_path"

  milestone "Wrote deployment environment file: $export_path"
}

if [ ! -f "$BUILD_SCRIPT" ]; then
  fail "build script not found at $BUILD_SCRIPT"
fi

OPENCLAW_AUTO_ENV_FILE=${OPENCLAW_AUTO_ENV_FILE:-"$SCRIPT_DIR/.sync-build.env"}
if [ -z "${OPENCLAW_ACTION:-}" ] && [ "${OPENCLAW_FORCE_INTERACTIVE:-0}" != "1" ] && [ -f "$OPENCLAW_AUTO_ENV_FILE" ]; then
  milestone "Detected existing environment file: $OPENCLAW_AUTO_ENV_FILE"
  milestone "Skipping prompts and running non-interactive build"
  set -a
  # shellcheck disable=SC1090
  . "$OPENCLAW_AUTO_ENV_FILE"
  set +a
  sh "$BUILD_SCRIPT"
  milestone "Non-interactive setup completed."
  exit 0
fi

choose_welcome_action
case "$OPENCLAW_ACTION" in
  install) ;;
  update)
    [ -f "$UPDATE_SCRIPT" ] || fail "update script not found at $UPDATE_SCRIPT"
    milestone "Running update workflow"
    sh "$UPDATE_SCRIPT"
    exit 0
    ;;
  image)
    [ -f "$IMAGE_SCRIPT" ] || fail "image helper script not found at $IMAGE_SCRIPT"
    milestone "Interactive custom-image publish workflow"
    cat << 'EOF2'
This workflow helps you publish a first custom OpenClaw image to GitHub Container Registry (GHCR).
You will be asked for:
  - GitHub user/org owner for ghcr.io
  - image name (repository name inside GHCR)
  - tag (version label)
  - push preference after build
Prerequisite:
  - Docker Engine + docker compose plugin installed and available as 'docker'
  - If docker is missing, this workflow attempts auto-install on Debian/Ubuntu
EOF2

    default_image_owner=$(env_or_default CUSTOM_OPENCLAW_IMAGE_OWNER "${GITHUB_USER:-}")
    default_image_name=$(env_or_default CUSTOM_OPENCLAW_IMAGE_NAME openclaw-agent-tools)
    default_image_tag=$(env_or_default CUSTOM_OPENCLAW_IMAGE_TAG "$(date +%Y-%m-%d)")

    ask_required_with_default CUSTOM_OPENCLAW_IMAGE_OWNER "GitHub user or organization (becomes ghcr.io/<owner>/...)" "$default_image_owner"
    ask_required_with_default CUSTOM_OPENCLAW_IMAGE_NAME "Image name/repository (becomes ghcr.io/<owner>/<image-name>:...)" "$default_image_name"
    ask_required_with_default CUSTOM_OPENCLAW_IMAGE_TAG "Image tag (version label after ':')" "$default_image_tag"
    CUSTOM_OPENCLAW_IMAGE_OWNER=$(normalize_ghcr_component "$CUSTOM_OPENCLAW_IMAGE_OWNER")
    CUSTOM_OPENCLAW_IMAGE_NAME=$(normalize_ghcr_component "$CUSTOM_OPENCLAW_IMAGE_NAME")

    if ask_yes_no "Push to GHCR after build?" "$(env_or_default CUSTOM_OPENCLAW_PUSH_DEFAULT y)"; then
      CUSTOM_OPENCLAW_PUSH=1
    else
      CUSTOM_OPENCLAW_PUSH=0
    fi

    CUSTOM_OPENCLAW_IMAGE="ghcr.io/$CUSTOM_OPENCLAW_IMAGE_OWNER/$CUSTOM_OPENCLAW_IMAGE_NAME:$CUSTOM_OPENCLAW_IMAGE_TAG"

    cat << EOF2

Computed image reference:
  $CUSTOM_OPENCLAW_IMAGE

Use this value later as:
  CUSTOM_OPENCLAW_IMAGE=$CUSTOM_OPENCLAW_IMAGE
  OPENCLAW_IMAGE=$CUSTOM_OPENCLAW_IMAGE
  SKIP_OPENCLAW_IMAGE_BUILD=1
EOF2

    if [ "$CUSTOM_OPENCLAW_PUSH" = "1" ]; then
      cat << 'EOF2'

Push prerequisites (required before docker push):
  1) A GitHub account/org with permission to publish packages for the selected owner.
  2) A Personal Access Token (classic) or fine-grained token with package write permissions.
  3) Docker login to GHCR, for example:
       echo "$CR_PAT" | docker login ghcr.io -u <github-user> --password-stdin
EOF2
    else
      cat << 'EOF2'

Push is disabled for this run. The image will be built locally only.
EOF2
    fi

    if ! ask_yes_no "Continue with build workflow using the computed image reference?" "y"; then
      fail "User aborted image workflow before build."
    fi

    export CUSTOM_OPENCLAW_IMAGE CUSTOM_OPENCLAW_PUSH
    milestone "Running image build workflow for $CUSTOM_OPENCLAW_IMAGE"
    sh "$IMAGE_SCRIPT"
    exit 0
    ;;
  backup)
    [ -f "$BACKUP_SCRIPT" ] || fail "backup script not found at $BACKUP_SCRIPT"
    milestone "Running backup workflow"
    sh "$BACKUP_SCRIPT"
    exit 0
    ;;
  add_tool)
    [ -f "$ADD_TOOL_SCRIPT" ] || fail "add_tool script not found at $ADD_TOOL_SCRIPT"
    milestone "Running add-tool workflow"
    sh "$ADD_TOOL_SCRIPT"
    exit 0
    ;;
  restore)
    [ -f "$RESTORE_SCRIPT" ] || fail "restore script not found at $RESTORE_SCRIPT"
    milestone "Running restore workflow"
    sh "$RESTORE_SCRIPT"
    exit 0
    ;;
  security)
    [ -f "$SECURITY_SCRIPT" ] || fail "security audit script not found at $SECURITY_SCRIPT"
    milestone "Running security workflow"
    sh "$SECURITY_SCRIPT"
    exit 0
    ;;
esac

milestone "Interactive OpenClaw setup started"

PRE_DEPLOY_BACKUP=0
BACKUP_INCLUDE_TRAEFIK=0
BACKUP_INCLUDE_OPENCLAW_REPO=0
BACKUP_EXTRA_PATHS=""
BACKUP_OUTPUT_PATH="$PWD/openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

ask_access_mode
ask_var OVH_ENDPOINT_API_KEY "OVH endpoint API key" ""
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  ask_var TRAEFIK_ACME_EMAIL "Traefik email for ACME certs" "$(env_or_default TRAEFIK_ACME_EMAIL admin@example.com)"
  ask_var OPENCLAW_DOMAIN "OpenClaw public domain (DNS must point to host)" "$(env_or_default OPENCLAW_DOMAIN openclaw.example.com)"
fi
ask_var OPENCLAW_TOKEN "OpenClaw gateway token (optional)" ""
ask_var OPENCLAW_DIR "Optional output directory for OpenClaw" "$(env_or_default OPENCLAW_DIR "$HOME/openclaw")"
ask_var OPENCLAW_CONFIG_DIR "Optional OpenClaw config directory" "$(env_or_default OPENCLAW_CONFIG_DIR "$HOME/.openclaw")"
ask_var OPENCLAW_WORKSPACE_DIR "Optional workspace directory" "$(env_or_default OPENCLAW_WORKSPACE_DIR "$HOME/.openclaw/workspace")"
if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  ask_var TRAEFIK_DIR "Optional Traefik directory" "$(env_or_default TRAEFIK_DIR "$HOME/docker/traefik")"
fi
ask_var OPENCLAW_USER "System user that should own OpenClaw files (usually your SSH user)" "$(env_or_default OPENCLAW_USER "$(id -un)")"
ask_var OPENCLAW_ENABLE_SIGNAL "Enable Signal channel setup (1=yes, 0=no)" "$(env_or_default OPENCLAW_ENABLE_SIGNAL 0)"
if [ "${OPENCLAW_ENABLE_SIGNAL:-0}" = "1" ]; then
  ask_var OPENCLAW_SIGNAL_ACCOUNT "Signal bot account number (E.164, e.g. +15551234567)" ""
  ask_var OPENCLAW_SIGNAL_ALLOW_FROM "Signal DM allowlist sender (optional E.164 or uuid:<id>)" ""
  ask_var OPENCLAW_SIGNAL_CLI_PATH "Signal CLI command/path inside container image" "$(env_or_default OPENCLAW_SIGNAL_CLI_PATH signal-cli)"
fi
ask_var OPENCLAW_ENABLE_GITHUB_SKILL "Enable GitHub skill prerequisites (1=yes, 0=no)" "$(env_or_default OPENCLAW_ENABLE_GITHUB_SKILL 0)"
if [ "${OPENCLAW_ENABLE_GITHUB_SKILL:-0}" = "1" ]; then
  ask_var OPENCLAW_GH_CLI_PATH "GitHub CLI command/path" "$(env_or_default OPENCLAW_GH_CLI_PATH gh)"
fi
ask_var OPENCLAW_ENABLE_HIMALAYA_SKILL "Enable Himalaya skill prerequisites (1=yes, 0=no)" "$(env_or_default OPENCLAW_ENABLE_HIMALAYA_SKILL 0)"
if [ "${OPENCLAW_ENABLE_HIMALAYA_SKILL:-0}" = "1" ]; then
  ask_var OPENCLAW_HIMALAYA_CLI_PATH "Himalaya CLI command/path" "$(env_or_default OPENCLAW_HIMALAYA_CLI_PATH himalaya)"
  ask_var OPENCLAW_HIMALAYA_REQUIRE_CONFIG "Require Himalaya config file exists (1=yes, 0=no)" "$(env_or_default OPENCLAW_HIMALAYA_REQUIRE_CONFIG 1)"
  ask_var OPENCLAW_HIMALAYA_CONFIG_PATH "Himalaya config file path" "$(env_or_default OPENCLAW_HIMALAYA_CONFIG_PATH "$OPENCLAW_CONFIG_DIR/himalaya/config.toml")"
fi
ask_var OPENCLAW_ENABLE_CODING_AGENT_SKILL "Enable coding-agent skill prerequisites (1=yes, 0=no)" "$(env_or_default OPENCLAW_ENABLE_CODING_AGENT_SKILL 0)"
if [ "${OPENCLAW_ENABLE_CODING_AGENT_SKILL:-0}" = "1" ]; then
  ask_var OPENCLAW_CODING_AGENT_BACKEND "Coding-agent backend (claude/codex/opencode/pi)" "$(env_or_default OPENCLAW_CODING_AGENT_BACKEND codex)"
fi
ask_var DRY_RUN "Dry-run mode (1=yes, 0=no)" "$(env_or_default DRY_RUN 0)"

if [ "$DRY_RUN" != "1" ]; then
  milestone "Optional pre-deploy backup"
  if ask_yes_no "Create a pre-deploy backup before running build.sh?" "y"; then
    PRE_DEPLOY_BACKUP=1
    if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
      if ask_yes_no "Include Traefik state ($TRAEFIK_DIR)?" "y"; then
        BACKUP_INCLUDE_TRAEFIK=1
      fi
    fi
    if ask_yes_no "Include full OpenClaw checkout ($OPENCLAW_DIR)?" "n"; then
      BACKUP_INCLUDE_OPENCLAW_REPO=1
    fi
    ask_optional_assign BACKUP_EXTRA_PATHS "Extra backup paths (space-separated, optional)" ""
    ask_optional_assign BACKUP_OUTPUT_PATH "Backup output archive path" "$BACKUP_OUTPUT_PATH"
  fi
else
  milestone "DRY_RUN=1 - skipping backup prompt"
fi

milestone "Configuration complete - reviewing values"

cat << EOF2
OPENCLAW_ACCESS_MODE=$OPENCLAW_ACCESS_MODE
OVH_ENDPOINT_API_KEY=<redacted>
OPENCLAW_TOKEN=<redacted>
OPENCLAW_DIR=$OPENCLAW_DIR
OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
OPENCLAW_USER=$OPENCLAW_USER
OPENCLAW_ENABLE_SIGNAL=$OPENCLAW_ENABLE_SIGNAL
OPENCLAW_ENABLE_GITHUB_SKILL=$OPENCLAW_ENABLE_GITHUB_SKILL
OPENCLAW_ENABLE_HIMALAYA_SKILL=$OPENCLAW_ENABLE_HIMALAYA_SKILL
OPENCLAW_ENABLE_CODING_AGENT_SKILL=$OPENCLAW_ENABLE_CODING_AGENT_SKILL
DRY_RUN=$DRY_RUN
PRE_DEPLOY_BACKUP=$PRE_DEPLOY_BACKUP
EOF2

if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  cat << EOF2
TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL
OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN
TRAEFIK_DIR=$TRAEFIK_DIR
EOF2
fi

if [ "${OPENCLAW_ENABLE_SIGNAL:-0}" = "1" ]; then
  cat << EOF2
OPENCLAW_SIGNAL_ACCOUNT=$OPENCLAW_SIGNAL_ACCOUNT
OPENCLAW_SIGNAL_ALLOW_FROM=$OPENCLAW_SIGNAL_ALLOW_FROM
OPENCLAW_SIGNAL_CLI_PATH=$OPENCLAW_SIGNAL_CLI_PATH
EOF2
fi

if [ "${OPENCLAW_ENABLE_GITHUB_SKILL:-0}" = "1" ]; then
  cat << EOF2
OPENCLAW_GH_CLI_PATH=$OPENCLAW_GH_CLI_PATH
EOF2
fi

if [ "${OPENCLAW_ENABLE_HIMALAYA_SKILL:-0}" = "1" ]; then
  cat << EOF2
OPENCLAW_HIMALAYA_CLI_PATH=$OPENCLAW_HIMALAYA_CLI_PATH
OPENCLAW_HIMALAYA_REQUIRE_CONFIG=$OPENCLAW_HIMALAYA_REQUIRE_CONFIG
OPENCLAW_HIMALAYA_CONFIG_PATH=$OPENCLAW_HIMALAYA_CONFIG_PATH
EOF2
fi

if [ "${OPENCLAW_ENABLE_CODING_AGENT_SKILL:-0}" = "1" ]; then
  cat << EOF2
OPENCLAW_CODING_AGENT_BACKEND=$OPENCLAW_CODING_AGENT_BACKEND
EOF2
fi

if [ "$PRE_DEPLOY_BACKUP" = "1" ]; then
  cat << EOF2
BACKUP_INCLUDE_TRAEFIK=$BACKUP_INCLUDE_TRAEFIK
BACKUP_INCLUDE_OPENCLAW_REPO=$BACKUP_INCLUDE_OPENCLAW_REPO
BACKUP_EXTRA_PATHS=$BACKUP_EXTRA_PATHS
BACKUP_OUTPUT_PATH=$BACKUP_OUTPUT_PATH
EOF2
fi

printf 'Proceed with these settings? [y/N]: '
read answer
case "$(to_lower "$answer")" in
  y | yes) ;;
  *)
    fail 'User aborted.'
    ;;
esac

milestone "Exporting environment variables"

export OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY
export OPENCLAW_TOKEN
export OPENCLAW_DIR OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE_DIR OPENCLAW_USER
export OPENCLAW_ENABLE_SIGNAL
export OPENCLAW_ENABLE_GITHUB_SKILL
export OPENCLAW_ENABLE_HIMALAYA_SKILL
export OPENCLAW_ENABLE_CODING_AGENT_SKILL
export DRY_RUN

if [ "${OPENCLAW_ENABLE_SIGNAL:-0}" = "1" ]; then
  export OPENCLAW_SIGNAL_ACCOUNT OPENCLAW_SIGNAL_ALLOW_FROM OPENCLAW_SIGNAL_CLI_PATH
fi

if [ "${OPENCLAW_ENABLE_GITHUB_SKILL:-0}" = "1" ]; then
  export OPENCLAW_GH_CLI_PATH
fi

if [ "${OPENCLAW_ENABLE_HIMALAYA_SKILL:-0}" = "1" ]; then
  export OPENCLAW_HIMALAYA_CLI_PATH OPENCLAW_HIMALAYA_REQUIRE_CONFIG OPENCLAW_HIMALAYA_CONFIG_PATH OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64
fi

if [ "${OPENCLAW_ENABLE_CODING_AGENT_SKILL:-0}" = "1" ]; then
  export OPENCLAW_CODING_AGENT_BACKEND
fi

if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  export TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN TRAEFIK_DIR
  export OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-https://$OPENCLAW_DOMAIN}
else
  export OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-http://127.0.0.1:18789}
fi

persist_env_file "${OPENCLAW_EXPORT_ENV_FILE:-}"

if [ "${OPENCLAW_GENERATE_ENV_ONLY:-0}" = "1" ]; then
  milestone "OPENCLAW_GENERATE_ENV_ONLY=1 - configuration captured; skipping backup and build."
  exit 0
fi

if [ "${OPENCLAW_ENABLE_SIGNAL:-0}" = "1" ]; then
  cat << 'EOF2'
- Signal setup enabled. Next steps after deploy:
  - Verify signal-cli registration/linking inside the container runtime context.
  - Run: openclaw pairing list signal
EOF2
fi

milestone "Running core setup script on SSH-capable host"

if [ "$PRE_DEPLOY_BACKUP" = "1" ]; then
  [ -f "$BACKUP_SCRIPT" ] || fail "backup script not found at $BACKUP_SCRIPT"
  milestone "Running pre-deploy backup"
  INCLUDE_TRAEFIK=$BACKUP_INCLUDE_TRAEFIK \
    INCLUDE_OPENCLAW_REPO=$BACKUP_INCLUDE_OPENCLAW_REPO \
    EXTRA_BACKUP_PATHS=$BACKUP_EXTRA_PATHS \
    BACKUP_OUTPUT=$BACKUP_OUTPUT_PATH \
    OPENCLAW_DIR=$OPENCLAW_DIR \
    OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR \
    TRAEFIK_DIR=${TRAEFIK_DIR:-$HOME/docker/traefik} \
    sh "$BACKUP_SCRIPT"
fi

sh "$BUILD_SCRIPT"

milestone "Interactive setup completed."

if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
  cat << EOF2
Success: OpenClaw should now be deployed.
- Access: https://$OPENCLAW_DOMAIN
- Check container logs: docker logs openclaw
- Device approvals: docker exec -it openclaw node dist/index.js devices list
EOF2
else
  cat << 'EOF2'
Success: OpenClaw should now be deployed in private ssh-tunnel mode.
- Tunnel command: ssh -N -L 18789:127.0.0.1:18789 <user>@<host>
- Local access URL after tunnel: http://127.0.0.1:18789
- Check container logs: docker logs openclaw
- Device approvals: docker exec -it openclaw node dist/index.js devices list
EOF2
fi
