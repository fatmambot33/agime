#!/usr/bin/env sh

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_env() {
  var_name=$1
  eval "var_value=\${$var_name-}"
  [ -n "$var_value" ] || fail "Environment variable $var_name is required"
}

run_cmd() {
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] $*"
    return 0
  fi
  "$@"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\\/&]/\\&/g'
}

render_template() {
  target=$1
  template=$2

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] render $template to $target"
    return 0
  fi

  [ -f "$template" ] || fail "Template not found: $template"
  tmp_file="${target}.tmp"
  sed \
    -e "s/__TRAEFIK_ACME_EMAIL__/$(escape_sed_replacement "$TRAEFIK_ACME_EMAIL")/g" \
    -e "s/__OPENCLAW_IMAGE__/$(escape_sed_replacement "$OPENCLAW_IMAGE")/g" \
    -e "s/__OPENCLAW_GATEWAY_BIND__/$(escape_sed_replacement "$OPENCLAW_GATEWAY_BIND")/g" \
    -e "s/__OPENCLAW_DOMAIN__/$(escape_sed_replacement "$OPENCLAW_DOMAIN")/g" \
    -e "s/__OPENCLAW_ALLOWED_ORIGIN__/$(escape_sed_replacement "$OPENCLAW_ALLOWED_ORIGIN")/g" \
    -e "s/__OPENCLAW_TOKEN__/$(escape_sed_replacement "$OPENCLAW_TOKEN")/g" \
    -e "s/__OVH_ENDPOINT_BASE_URL__/$(escape_sed_replacement "$OVH_ENDPOINT_BASE_URL")/g" \
    -e "s/__OVH_ENDPOINT_API_KEY__/$(escape_sed_replacement "$OVH_ENDPOINT_API_KEY")/g" \
    -e "s/__OVH_ENDPOINT_MODEL__/$(escape_sed_replacement "$OVH_ENDPOINT_MODEL")/g" \
    "$template" >"$tmp_file"
  mv "$tmp_file" "$target"
}

extract_openclaw_token() {
  env_file=$1
  [ -f "$env_file" ] || return 1
  token=$(grep '^OPENCLAW_GATEWAY_TOKEN=' "$env_file" | tail -n 1 | cut -d '=' -f 2- || true)
  [ -n "$token" ] || return 1
  printf '%s' "$token"
}
