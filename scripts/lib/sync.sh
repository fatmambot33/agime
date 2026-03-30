#!/usr/bin/env sh
# shellcheck shell=sh

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/scripts/lib/common.sh"

sync_load_config() {
  if [ -f "$SYNC_CONFIG_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$SYNC_CONFIG_FILE"
    set +a
  fi
}

sync_validate_remote_entrypoint() {
  case "$SYNC_REMOTE_ENTRYPOINT" in
    build.sh | update.sh | backup.sh | restore.sh) ;;
    *)
      fail "SYNC_REMOTE_ENTRYPOINT must be one of: build.sh, update.sh, backup.sh, restore.sh"
      ;;
  esac
}

sync_validate_requirements() {
  require_nonempty "REMOTE_HOST" "$REMOTE_HOST"
  sync_validate_remote_entrypoint

  if [ "$SYNC_REMOTE_ENTRYPOINT" = "build.sh" ]; then
    [ -n "${OVH_ENDPOINT_API_KEY:-}" ] && return 0
    if sync_env_file_has_nonempty_ovh_key "$SYNC_LOCAL_ENV_FILE"; then
      return 0
    fi
    fail "OVH_ENDPOINT_API_KEY is required for build.sh remote runs"
  fi
}

sync_set_default_items_if_unset() {
  [ -n "${SYNC_ITEMS:-}" ] && return 0

  access_mode=${OPENCLAW_ACCESS_MODE:-ssh-tunnel}
  case "$access_mode" in
    ssh-tunnel | public) ;;
    *) access_mode=ssh-tunnel ;;
  esac

  case "$SYNC_REMOTE_ENTRYPOINT" in
    backup.sh)
      SYNC_ITEMS="backup.sh"
      ;;
    restore.sh)
      SYNC_ITEMS="restore.sh"
      ;;
    update.sh)
      SYNC_ITEMS="update.sh backup.sh build.sh scripts templates/openclaw.json.tmpl"
      if [ "$access_mode" = "public" ]; then
        SYNC_ITEMS="$SYNC_ITEMS templates/openclaw-compose.public.yml.tmpl templates/traefik-compose.yml.tmpl"
      else
        SYNC_ITEMS="$SYNC_ITEMS templates/openclaw-compose.ssh-tunnel.yml.tmpl"
      fi
      ;;
    build.sh)
      SYNC_ITEMS="build.sh scripts templates/openclaw.json.tmpl"
      if [ "$access_mode" = "public" ]; then
        SYNC_ITEMS="$SYNC_ITEMS templates/openclaw-compose.public.yml.tmpl templates/traefik-compose.yml.tmpl"
      else
        SYNC_ITEMS="$SYNC_ITEMS templates/openclaw-compose.ssh-tunnel.yml.tmpl"
      fi
      ;;
  esac
}

sync_env_file_has_nonempty_ovh_key() {
  env_file=${1-}
  [ -n "$env_file" ] && [ -f "$env_file" ] || return 1

  awk '
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

sync_print_effective_config() {
  printf 'sync.sh effective config:\n'
  printf '  REMOTE_HOST=%s\n' "$REMOTE_HOST"
  printf '  REMOTE_DIR=%s\n' "$REMOTE_DIR"
  printf '  SYNC_REMOTE_ENTRYPOINT=%s\n' "$SYNC_REMOTE_ENTRYPOINT"
  printf '  SYNC_REMOTE_ENV_FILE=%s\n' "$SYNC_REMOTE_ENV_FILE"
  printf '  SYNC_LOCAL_ENV_FILE=%s\n' "$SYNC_LOCAL_ENV_FILE"
  printf '  SYNC_ITEMS=%s\n' "$SYNC_ITEMS"
}

sync_upload_and_run() {
  remote_dir_scp=$(canonicalize_home_path "$REMOTE_DIR")
  remote_dir_ssh=$(remote_home_path "$remote_dir_scp")

  ssh $SSH_BASE_ARGS "$REMOTE_HOST" "mkdir -p \"$remote_dir_ssh\""
  # shellcheck disable=SC2086
  scp $SSH_BASE_ARGS -r $SYNC_ITEMS "$REMOTE_HOST:$remote_dir_scp/"

  remote_env_setup=""
  if [ -n "$SYNC_REMOTE_ENV_FILE" ] && [ -f "$SYNC_LOCAL_ENV_FILE" ]; then
    scp $SSH_BASE_ARGS "$SYNC_LOCAL_ENV_FILE" "$REMOTE_HOST:$remote_dir_scp/$SYNC_REMOTE_ENV_FILE"
    remote_env_setup="set -a && . './$SYNC_REMOTE_ENV_FILE' && set +a && "
  fi

  ssh $SSH_BASE_ARGS "$REMOTE_HOST" "cd \"$remote_dir_ssh\" && chmod +x ./*.sh && ${remote_env_setup}./$SYNC_REMOTE_ENTRYPOINT"
  ssh $SSH_BASE_ARGS -O exit "$REMOTE_HOST" > /dev/null 2>&1 || true
}
