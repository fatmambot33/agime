#!/usr/bin/env sh
# shellcheck shell=sh

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/scripts/lib/common.sh"

SYNC_ALLOWED_CONFIG_KEYS='REMOTE_HOST REMOTE_DIR SYNC_REMOTE_ENTRYPOINT SYNC_REMOTE_ENV_FILE SYNC_LOCAL_ENV_FILE OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY OPENCLAW_TOKEN TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN GIT_PULL RUN_BACKUP RUN_BUILD BACKUP_OUTPUT RESTORE_ARCHIVE RESTORE_ROOT RESTORE_FORCE INCLUDE_TRAEFIK INCLUDE_OPENCLAW_REPO EXTRA_BACKUP_PATHS'
SYNC_REMOTE_ENV_KEYS='OPENCLAW_ACCESS_MODE OVH_ENDPOINT_API_KEY OPENCLAW_TOKEN TRAEFIK_ACME_EMAIL OPENCLAW_DOMAIN GIT_PULL RUN_BACKUP RUN_BUILD BACKUP_OUTPUT RESTORE_ARCHIVE RESTORE_ROOT RESTORE_FORCE INCLUDE_TRAEFIK INCLUDE_OPENCLAW_REPO EXTRA_BACKUP_PATHS'

sync_load_config() {
  if [ -f "$SYNC_CONFIG_FILE" ]; then
    sync_parse_key_value_file "$SYNC_CONFIG_FILE"
  fi

  if [ -f "$SYNC_LOCAL_ENV_FILE" ] && [ "$SYNC_LOCAL_ENV_FILE" != "$SYNC_CONFIG_FILE" ]; then
    sync_parse_key_value_file "$SYNC_LOCAL_ENV_FILE"
  fi
}

sync_parse_key_value_file() {
  config_file=$1

  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    case "$raw_line" in
      '' | '#'*)
        continue
        ;;
    esac

    case "$raw_line" in
      *=*) ;;
      *) fail "Invalid config line (expected KEY=VALUE): $raw_line" ;;
    esac

    key=${raw_line%%=*}
    value=${raw_line#*=}

    sync_validate_key "$key"
    value=$(sync_strip_wrapping_quotes "$value")
    sync_validate_value "$key" "$value"

    sync_assign_key "$key" "$value"
  done < "$config_file"
}

sync_validate_key() {
  key=$1
  case "$key" in
    '' | *[!A-Z0-9_]*)
      fail "Invalid config key: $key"
      ;;
  esac

  case " $SYNC_ALLOWED_CONFIG_KEYS " in
    *" $key "*) ;;
    *) fail "Unsupported config key: $key" ;;
  esac
}

sync_validate_value() {
  key=$1
  value=$2

  case "$value" in
    *\"* | *\`* | *\$* | *\;* | *\|* | *\&* | *\<* | *\>* | *\(* | *\)* | *\{* | *\}* | *\[* | *\]* | *\!* | *\?* | *\**)
      fail "$key contains unsafe shell characters"
      ;;
  esac

  if printf '%s' "$value" | LC_ALL=C grep -q '[^ -~]'; then
    fail "$key contains non-printable characters"
  fi
}

sync_strip_wrapping_quotes() {
  value=$1
  case "$value" in
    '"'*)
      case "$value" in
        *'"') printf '%s' "${value#\"}" | sed 's/"$//' ;;
        *) printf '%s' "$value" ;;
      esac
      ;;
    "'"*)
      case "$value" in
        *"'") printf '%s' "${value#\'}" | sed "s/'$//" ;;
        *) printf '%s' "$value" ;;
      esac
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

sync_assign_key() {
  key=$1
  value=$2

  case "$key" in
    REMOTE_HOST) REMOTE_HOST=$value ;;
    REMOTE_DIR) REMOTE_DIR=$value ;;
    SYNC_REMOTE_ENTRYPOINT) SYNC_REMOTE_ENTRYPOINT=$value ;;
    SYNC_REMOTE_ENV_FILE) SYNC_REMOTE_ENV_FILE=$value ;;
    SYNC_LOCAL_ENV_FILE) SYNC_LOCAL_ENV_FILE=$value ;;
    OPENCLAW_ACCESS_MODE) OPENCLAW_ACCESS_MODE=$value ;;
    OVH_ENDPOINT_API_KEY) OVH_ENDPOINT_API_KEY=$value ;;
    OPENCLAW_TOKEN) OPENCLAW_TOKEN=$value ;;
    TRAEFIK_ACME_EMAIL) TRAEFIK_ACME_EMAIL=$value ;;
    OPENCLAW_DOMAIN) OPENCLAW_DOMAIN=$value ;;
    GIT_PULL) GIT_PULL=$value ;;
    RUN_BACKUP) RUN_BACKUP=$value ;;
    RUN_BUILD) RUN_BUILD=$value ;;
    BACKUP_OUTPUT) BACKUP_OUTPUT=$value ;;
    RESTORE_ARCHIVE) RESTORE_ARCHIVE=$value ;;
    RESTORE_ROOT) RESTORE_ROOT=$value ;;
    RESTORE_FORCE) RESTORE_FORCE=$value ;;
    INCLUDE_TRAEFIK) INCLUDE_TRAEFIK=$value ;;
    INCLUDE_OPENCLAW_REPO) INCLUDE_OPENCLAW_REPO=$value ;;
    EXTRA_BACKUP_PATHS) EXTRA_BACKUP_PATHS=$value ;;
  esac
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
  if [ -n "${SYNC_ITEMS:-}" ]; then
    fail "SYNC_ITEMS is retired. Use SYNC_ITEMS_FILE with a validated newline-delimited manifest."
  fi

  if [ -n "${SYNC_ITEMS_FILE:-}" ]; then
    sync_validate_items_file "$SYNC_ITEMS_FILE"
    return 0
  fi

  SYNC_ITEMS_FILE=$(sync_generate_default_manifest)
}

sync_generate_default_manifest() {
  access_mode=$(sync_resolve_access_mode)
  tmp_manifest=$(mktemp)

  case "$SYNC_REMOTE_ENTRYPOINT" in
    backup.sh)
      printf '%s\n' 'backup.sh' > "$tmp_manifest"
      ;;
    restore.sh)
      printf '%s\n' 'restore.sh' > "$tmp_manifest"
      ;;
    build.sh | update.sh)
      if [ "$SYNC_REMOTE_ENTRYPOINT" = "update.sh" ]; then
        printf '%s\n' 'update.sh' 'backup.sh' 'build.sh' > "$tmp_manifest"
      else
        printf '%s\n' 'build.sh' > "$tmp_manifest"
      fi
      printf '%s\n' 'scripts' 'templates/openclaw.json.tmpl' >> "$tmp_manifest"
      if [ "$access_mode" = "public" ]; then
        printf '%s\n' 'templates/openclaw-compose.public.yml.tmpl' 'templates/traefik-compose.yml.tmpl' >> "$tmp_manifest"
      else
        printf '%s\n' 'templates/openclaw-compose.ssh-tunnel.yml.tmpl' >> "$tmp_manifest"
      fi
      ;;
  esac

  sync_validate_items_file "$tmp_manifest"
  printf '%s' "$tmp_manifest"
}

sync_validate_items_file() {
  items_file=$1
  [ -f "$items_file" ] || fail "SYNC_ITEMS_FILE not found: $items_file"

  while IFS= read -r item || [ -n "$item" ]; do
    case "$item" in
      '' | '#'*)
        continue
        ;;
    esac

    case "$item" in
      /* | *'..'*)
        fail "Invalid sync manifest item path: $item"
        ;;
    esac

    case "$item" in
      *[!A-Za-z0-9._/:-]*)
        fail "Invalid sync manifest item characters: $item"
        ;;
    esac

    [ -e "$SCRIPT_DIR/$item" ] || fail "Sync manifest item does not exist in repo: $item"
  done < "$items_file"
}

sync_resolve_access_mode() {
  access_mode=${OPENCLAW_ACCESS_MODE:-}
  case "$access_mode" in
    ssh-tunnel | public)
      printf '%s' "$access_mode"
      return 0
      ;;
  esac

  access_mode=$(sync_extract_access_mode_from_env_file "$SYNC_LOCAL_ENV_FILE" || true)
  case "$access_mode" in
    ssh-tunnel | public)
      printf '%s' "$access_mode"
      return 0
      ;;
  esac

  printf 'ssh-tunnel'
}

sync_extract_access_mode_from_env_file() {
  env_file=${1-}
  [ -n "$env_file" ] && [ -f "$env_file" ] || return 1

  awk '
    /^[[:space:]]*OPENCLAW_ACCESS_MODE=/ {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      gsub(/^["'"'"']/, "", value)
      gsub(/["'"'"']$/, "", value)
      if (value == "ssh-tunnel" || value == "public") {
        print value
        found = 1
      }
      exit 0
    }
    END { exit(found ? 0 : 1) }
  ' "$env_file"
}

sync_env_file_has_nonempty_ovh_key() {
  env_file=${1-}
  [ -n "$env_file" ] && [ -f "$env_file" ] || return 1

  awk '
    /^[[:space:]]*OVH_ENDPOINT_API_KEY=/ {
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

sync_shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\''/g")"
}

sync_build_remote_env_prefix() {
  prefix=''
  for key in $SYNC_REMOTE_ENV_KEYS; do
    eval "value=\${$key-}"
    [ -n "$value" ] || continue
    prefix="$prefix$key=$(sync_shell_quote "$value") "
  done
  printf '%s' "$prefix"
}

sync_print_effective_config() {
  printf 'sync.sh effective config:\n'
  printf '  REMOTE_HOST=%s\n' "$REMOTE_HOST"
  printf '  REMOTE_DIR=%s\n' "$REMOTE_DIR"
  printf '  SYNC_REMOTE_ENTRYPOINT=%s\n' "$SYNC_REMOTE_ENTRYPOINT"
  printf '  SYNC_REMOTE_ENV_FILE=%s\n' "$SYNC_REMOTE_ENV_FILE"
  printf '  SYNC_LOCAL_ENV_FILE=%s\n' "$SYNC_LOCAL_ENV_FILE"
  printf '  SYNC_ITEMS_FILE=%s\n' "$SYNC_ITEMS_FILE"
}

sync_upload_and_run() {
  remote_dir_scp=$(canonicalize_home_path "$REMOTE_DIR")
  remote_dir_ssh=$(remote_home_path "$remote_dir_scp")
  remote_env_prefix=$(sync_build_remote_env_prefix)

  ssh $SSH_BASE_ARGS "$REMOTE_HOST" "mkdir -p \"$remote_dir_ssh\""

  set --
  while IFS= read -r item || [ -n "$item" ]; do
    case "$item" in
      '' | '#'*)
        continue
        ;;
    esac
    set -- "$@" "$item"
  done < "$SYNC_ITEMS_FILE"

  [ "$#" -gt 0 ] || fail "Sync manifest is empty: $SYNC_ITEMS_FILE"
  # shellcheck disable=SC2086
  scp $SSH_BASE_ARGS -r "$@" "$REMOTE_HOST:$remote_dir_scp/"

  ssh $SSH_BASE_ARGS "$REMOTE_HOST" "cd \"$remote_dir_ssh\" && chmod +x ./*.sh && env ${remote_env_prefix}./$SYNC_REMOTE_ENTRYPOINT"
  ssh $SSH_BASE_ARGS -O exit "$REMOTE_HOST" > /dev/null 2>&1 || true

  case "${SYNC_ITEMS_FILE:-}" in
    /tmp/*)
      rm -f "$SYNC_ITEMS_FILE"
      ;;
  esac
}
