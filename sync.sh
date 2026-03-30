#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYNC_CONFIG_FILE=${SYNC_CONFIG_FILE:-"$SCRIPT_DIR/sync.conf"}

REMOTE_HOST=${REMOTE_HOST:-my-vps}
REMOTE_DIR=${REMOTE_DIR:-/tmp/agime}
SYNC_REMOTE_ENV_FILE=${SYNC_REMOTE_ENV_FILE:-"$(basename "$SYNC_CONFIG_FILE")"}
SYNC_LOCAL_ENV_FILE=${SYNC_LOCAL_ENV_FILE:-"$SYNC_CONFIG_FILE"}
SYNC_REMOTE_CONFIG_PRIORITY=${SYNC_REMOTE_CONFIG_PRIORITY:-1}
SSH_CONTROL_PERSIST_SECONDS=${SSH_CONTROL_PERSIST_SECONDS:-600}
SSH_CONTROL_PATH=${SSH_CONTROL_PATH:-"$HOME/.ssh/agime-sync-%r@%h:%p"}
SYNC_ALLOW_ABSOLUTE_REMOTE_DIR=${SYNC_ALLOW_ABSOLUTE_REMOTE_DIR:-0}
SSH_BASE_ARGS="-o ControlMaster=auto -o ControlPersist=${SSH_CONTROL_PERSIST_SECONDS} -o ControlPath=$SSH_CONTROL_PATH"

canonicalize_home_path() {
  value=$1
  home_dir=${HOME:-}
  [ -n "$home_dir" ] || {
    printf '%s' "$value"
    return 0
  }

  case "$value" in
    "$home_dir")
      printf '~'
      ;;
    "$home_dir"/*)
      printf '~/%s' "${value#"$home_dir"/}"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

normalize_remote_dir() {
  REMOTE_DIR=$(canonicalize_home_path "$REMOTE_DIR")
}

remote_home_path() {
  value=$1
  case "$value" in
    "~")
      printf '$HOME'
      ;;
    "~/"*)
      printf '$HOME/%s' "${value#\~/}"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

refresh_remote_dir_ssh() {
  REMOTE_DIR_SSH=$(remote_home_path "$REMOTE_DIR")
}

normalize_shared_home_paths() {
  env_file=$1
  [ -f "$env_file" ] || return 0

  tmp_file=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      OPENCLAW_DIR=* | OPENCLAW_CONFIG_DIR=* | OPENCLAW_WORKSPACE_DIR=* | TRAEFIK_DIR=* | OPENCLAW_JSON_BACKUP_DIR=*)
        key=${line%%=*}
        value=${line#*=}
        value=$(canonicalize_home_path "$value")
        printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
        ;;
      *)
        printf '%s\n' "$line" >> "$tmp_file"
        ;;
    esac
  done < "$env_file"

  mv "$tmp_file" "$env_file"
}

try_download_remote_config() {
  ssh $SSH_BASE_ARGS "$REMOTE_HOST" "test -f \"$REMOTE_DIR_SSH/$SYNC_REMOTE_ENV_FILE\"" || return 1
  mkdir -p "$(dirname "$SYNC_LOCAL_ENV_FILE")"
  scp $SSH_BASE_ARGS "$REMOTE_HOST:$REMOTE_DIR/$SYNC_REMOTE_ENV_FILE" "$SYNC_LOCAL_ENV_FILE"
  normalize_shared_home_paths "$SYNC_LOCAL_ENV_FILE"
  chmod 600 "$SYNC_LOCAL_ENV_FILE"
  printf 'sync.sh: downloaded %s from %s:%s/%s\n' "$SYNC_LOCAL_ENV_FILE" "$REMOTE_HOST" "$REMOTE_DIR" "$SYNC_REMOTE_ENV_FILE"
}

bootstrap_local_config() {
  example_file=$SCRIPT_DIR/sync.conf.example
  if [ ! -f "$example_file" ]; then
    cat >&2 << EOF
sync.sh error:
  could not bootstrap local config.
  missing $example_file
EOF
    exit 1
  fi

  mkdir -p "$(dirname "$SYNC_LOCAL_ENV_FILE")"
  cp "$example_file" "$SYNC_LOCAL_ENV_FILE"

  normalize_remote_dir
  upsert_env_key "REMOTE_HOST" "$REMOTE_HOST"
  upsert_env_key "REMOTE_DIR" "$REMOTE_DIR"
  normalize_shared_home_paths "$SYNC_LOCAL_ENV_FILE"
  chmod 600 "$SYNC_LOCAL_ENV_FILE"
  printf 'sync.sh: local config ready at %s\n' "$SYNC_LOCAL_ENV_FILE"
}

upsert_env_key() {
  key=$1
  value=$2
  tmp_file=$(mktemp)
  awk -F= -v k="$key" '$1 != k { print }' "$SYNC_LOCAL_ENV_FILE" > "$tmp_file"
  printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
  mv "$tmp_file" "$SYNC_LOCAL_ENV_FILE"
}

normalize_remote_dir
refresh_remote_dir_ssh

if [ ! -f "$SYNC_LOCAL_ENV_FILE" ]; then
  try_download_remote_config || bootstrap_local_config
fi

if [ -f "$SYNC_CONFIG_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$SYNC_CONFIG_FILE"
  set +a
fi
normalize_remote_dir
refresh_remote_dir_ssh

OPENCLAW_ACTION=${OPENCLAW_ACTION:-}
SYNC_REMOTE_ENTRYPOINT=${SYNC_REMOTE_ENTRYPOINT:-build.sh}
SYNC_MIRROR_ENV_FILE=${SYNC_MIRROR_ENV_FILE:-0}
SYNC_PRINT_CONFIG=${SYNC_PRINT_CONFIG:-0}
SYNC_ITEMS=${SYNC_ITEMS:-"build.sh backup.sh update.sh image.sh restore.sh scripts templates docs README.md"}

ssh_exec() {
  # Keep sync orchestration local: only the wrapped command runs remotely.
  ssh $SSH_BASE_ARGS "$@"
}

scp_exec() {
  scp $SSH_BASE_ARGS "$@"
}

remote_env_exists() {
  [ -n "$SYNC_REMOTE_ENV_FILE" ] || return 1
  ssh_exec "$REMOTE_HOST" "test -f \"$REMOTE_DIR_SSH/$SYNC_REMOTE_ENV_FILE\""
}

cleanup_ssh_master() {
  ssh_exec -O exit "$REMOTE_HOST" > /dev/null 2>&1 || true
}

print_effective_config() {
  printf '%s\n' "sync.sh effective config:"
  printf '  SYNC_CONFIG_FILE=%s\n' "$SYNC_CONFIG_FILE"
  printf '  REMOTE_HOST=%s\n' "$REMOTE_HOST"
  printf '  REMOTE_DIR=%s\n' "$REMOTE_DIR"
  printf '  SYNC_REMOTE_ENTRYPOINT=%s\n' "$SYNC_REMOTE_ENTRYPOINT"
  printf '  SYNC_REMOTE_ENV_FILE=%s\n' "${SYNC_REMOTE_ENV_FILE:-<none>}"
  printf '  SYNC_LOCAL_ENV_FILE=%s\n' "$SYNC_LOCAL_ENV_FILE"
  printf '  SYNC_MIRROR_ENV_FILE=%s\n' "$SYNC_MIRROR_ENV_FILE"
  printf '  OPENCLAW_ACTION=%s\n' "${OPENCLAW_ACTION:-<none>}"
  printf '  SSH_CONTROL_PERSIST_SECONDS=%s\n' "$SSH_CONTROL_PERSIST_SECONDS"
  printf '  SSH_CONTROL_PATH=%s\n' "$SSH_CONTROL_PATH"
  printf '  SYNC_ITEMS=%s\n' "$SYNC_ITEMS"
}

if [ "$SYNC_PRINT_CONFIG" = "1" ]; then
  print_effective_config
fi

trap 'cleanup_ssh_master' EXIT INT TERM

REMOTE_ENV_PRESENT=0
if [ "$SYNC_REMOTE_CONFIG_PRIORITY" = "1" ] && remote_env_exists; then
  REMOTE_ENV_PRESENT=1
  try_download_remote_config || true
  if [ -f "$SYNC_LOCAL_ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$SYNC_LOCAL_ENV_FILE"
    set +a
    normalize_remote_dir
    refresh_remote_dir_ssh
  fi
fi

UPLOAD_ITEMS=$SYNC_ITEMS
if [ "$REMOTE_ENV_PRESENT" != "1" ] && [ -f "$SYNC_CONFIG_FILE" ]; then
  case " $UPLOAD_ITEMS " in
    *" $SYNC_CONFIG_FILE "*) ;;
    *) UPLOAD_ITEMS="$UPLOAD_ITEMS $SYNC_CONFIG_FILE" ;;
  esac
fi

ENV_UPLOAD_SOURCE=""
if [ -n "$SYNC_REMOTE_ENV_FILE" ]; then
  if [ "$REMOTE_ENV_PRESENT" = "1" ]; then
    ENV_UPLOAD_SOURCE=""
  elif [ -f "$SYNC_LOCAL_ENV_FILE" ]; then
    ENV_UPLOAD_SOURCE=$SYNC_LOCAL_ENV_FILE
  elif [ -f "$SYNC_REMOTE_ENV_FILE" ]; then
    ENV_UPLOAD_SOURCE=$SYNC_REMOTE_ENV_FILE
  fi
fi

env_file_has_nonempty_ovh_key() {
  env_file=${1-}
  [ -n "$env_file" ] && [ -f "$env_file" ] && awk '
    /^[[:space:]]*(export[[:space:]]+)?OVH_ENDPOINT_API_KEY=/ {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      if (value != "" && value != "\"\"" && value != "'"'"''"'"'") {
        found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$env_file"
}

print_preflight_warnings() {
  if [ "$SYNC_REMOTE_ENTRYPOINT" != "build.sh" ] || [ -n "${OVH_ENDPOINT_API_KEY:-}" ]; then
    return
  fi

  if env_file_has_nonempty_ovh_key "$ENV_UPLOAD_SOURCE"; then
    return
  fi

  warning_target=$SYNC_CONFIG_FILE
  if [ -n "$ENV_UPLOAD_SOURCE" ]; then
    warning_target=$ENV_UPLOAD_SOURCE
  fi

  cat >&2 << EOF
sync.sh preflight warning:
  SYNC_REMOTE_ENTRYPOINT=build.sh requires OVH_ENDPOINT_API_KEY.
  It is currently empty in the loaded environment/config, so remote build.sh is expected to fail.
  Set OVH_ENDPOINT_API_KEY in $warning_target (or export it before running sync.sh) and retry.
EOF
}

is_loopback_remote_host() {
  case "$REMOTE_HOST" in
    localhost | localhost:* | 127.0.0.1 | 127.0.0.1:* | ::1 | ::1:*)
      return 0
      ;;
    *@localhost | *@localhost:* | *@127.0.0.1 | *@127.0.0.1:* | *@::1 | *@::1:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_remote_dir_path() {
  case "$REMOTE_DIR" in
    /Users/*)
      if [ "$SYNC_ALLOW_ABSOLUTE_REMOTE_DIR" = "1" ] || is_loopback_remote_host; then
        return
      fi
      cat >&2 << EOF
sync.sh preflight error:
  REMOTE_DIR=$REMOTE_DIR looks like a local macOS home path.
  On Linux VPS hosts this usually fails with "mkdir: cannot create directory '/Users': Permission denied".
  Use a VPS path such as REMOTE_DIR=~/agime (recommended) or set SYNC_ALLOW_ABSOLUTE_REMOTE_DIR=1 to bypass this guard.
EOF
      exit 1
      ;;
  esac
}

print_preflight_warnings
validate_remote_dir_path

SKIP_ENV_EXTRA_UPLOAD=0
if [ -n "$ENV_UPLOAD_SOURCE" ] && [ -f "$SYNC_CONFIG_FILE" ]; then
  case " $UPLOAD_ITEMS " in
    *" $SYNC_CONFIG_FILE "*)
      if [ "$ENV_UPLOAD_SOURCE" = "$SYNC_CONFIG_FILE" ] && [ "$SYNC_REMOTE_ENV_FILE" = "$(basename "$SYNC_CONFIG_FILE")" ]; then
        SKIP_ENV_EXTRA_UPLOAD=1
      fi
      ;;
  esac
fi

ssh_exec "$REMOTE_HOST" "mkdir -p \"$REMOTE_DIR_SSH\""
set -- $UPLOAD_ITEMS
scp_exec -r "$@" "$REMOTE_HOST:$REMOTE_DIR/"
if [ -n "$ENV_UPLOAD_SOURCE" ] && [ -n "$SYNC_REMOTE_ENV_FILE" ] && [ "$SKIP_ENV_EXTRA_UPLOAD" != "1" ]; then
  scp_exec "$ENV_UPLOAD_SOURCE" "$REMOTE_HOST:$REMOTE_DIR/$SYNC_REMOTE_ENV_FILE"
fi

if [ -n "$SYNC_REMOTE_ENV_FILE" ]; then
  REMOTE_ENV_SETUP="set -a && . './$SYNC_REMOTE_ENV_FILE' && set +a && "
else
  REMOTE_ENV_SETUP=""
fi

case "$SYNC_REMOTE_ENTRYPOINT" in
  configure.sh)
    if [ -n "$OPENCLAW_ACTION" ]; then
      ssh_exec -t "$REMOTE_HOST" "cd \"$REMOTE_DIR_SSH\" && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}OPENCLAW_ACTION='$OPENCLAW_ACTION' OPENCLAW_EXPORT_ENV_FILE='${SYNC_REMOTE_ENV_FILE:-}' ./configure.sh"
    else
      ssh_exec -t "$REMOTE_HOST" "cd \"$REMOTE_DIR_SSH\" && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}OPENCLAW_EXPORT_ENV_FILE='${SYNC_REMOTE_ENV_FILE:-}' ./configure.sh"
    fi
    ;;
  build.sh)
    ssh_exec "$REMOTE_HOST" "cd \"$REMOTE_DIR_SSH\" && chmod +x ./*.sh && ${REMOTE_ENV_SETUP}./build.sh"
    ;;
  *)
    printf 'Error: unsupported SYNC_REMOTE_ENTRYPOINT: %s\n' "$SYNC_REMOTE_ENTRYPOINT" >&2
    exit 1
    ;;
esac

if [ "$SYNC_MIRROR_ENV_FILE" = "1" ] && [ -n "$SYNC_REMOTE_ENV_FILE" ]; then
  mkdir -p "$(dirname "$SYNC_LOCAL_ENV_FILE")"
  scp_exec "$REMOTE_HOST:$REMOTE_DIR/$SYNC_REMOTE_ENV_FILE" "$SYNC_LOCAL_ENV_FILE"
  normalize_shared_home_paths "$SYNC_LOCAL_ENV_FILE"
  chmod 600 "$SYNC_LOCAL_ENV_FILE"
fi
