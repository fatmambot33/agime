#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

initialize_defaults() {
  CURRENT_USER=$(id -un)
  HOME_DIR=${HOME:-"$(getent passwd "$CURRENT_USER" | cut -d : -f 6 2> /dev/null || printf '/home/%s' "$CURRENT_USER")"}
  OPENCLAW_ACCESS_MODE=${OPENCLAW_ACCESS_MODE:-"ssh-tunnel"}
  TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL:-""}
  OPENCLAW_DOMAIN=${OPENCLAW_DOMAIN:-""}
  OPENCLAW_DIR=${OPENCLAW_DIR:-"$HOME_DIR/openclaw"}
  OPENCLAW_CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-"$HOME_DIR/.openclaw"}
  OPENCLAW_WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR:-"$OPENCLAW_CONFIG_DIR/workspace"}
  OPENCLAW_JSON_BACKUP_DIR=${OPENCLAW_JSON_BACKUP_DIR:-"$HOME_DIR/openclaw-backups"}
  TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME_DIR/docker/traefik"}
  OPENCLAW_REPO=${OPENCLAW_REPO:-"https://github.com/openclaw/openclaw.git"}
  OPENCLAW_IMAGE="ghcr.io/openclaw/openclaw:latest"
  OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-"lan"}
  OVH_ENDPOINT_BASE_URL=${OVH_ENDPOINT_BASE_URL:-"https://oai.endpoints.kepler.ai.cloud.ovh.net/v1"}
  OVH_ENDPOINT_MODEL=${OVH_ENDPOINT_MODEL:-"gpt-oss-120b"}
  OPENCLAW_USER=${OPENCLAW_USER:-"$CURRENT_USER"}
  TRAEFIK_COMPOSE_TEMPLATE=${TRAEFIK_COMPOSE_TEMPLATE:-"$SCRIPT_DIR/templates/traefik-compose.yml.tmpl"}
  OPENCLAW_COMPOSE_TEMPLATE_PUBLIC=${OPENCLAW_COMPOSE_TEMPLATE_PUBLIC:-"$SCRIPT_DIR/templates/openclaw-compose.public.yml.tmpl"}
  OPENCLAW_COMPOSE_TEMPLATE_SSH_TUNNEL=${OPENCLAW_COMPOSE_TEMPLATE_SSH_TUNNEL:-"$SCRIPT_DIR/templates/openclaw-compose.ssh-tunnel.yml.tmpl"}
  OPENCLAW_JSON_TEMPLATE=${OPENCLAW_JSON_TEMPLATE:-"$SCRIPT_DIR/templates/openclaw.json.tmpl"}
  SKIP_DOCKER_GROUP_SETUP=${SKIP_DOCKER_GROUP_SETUP:-"0"}
  POST_BUILD_TEST=${POST_BUILD_TEST:-"1"}
  POST_BUILD_TEST_ATTEMPTS=${POST_BUILD_TEST_ATTEMPTS:-"40"}
  POST_BUILD_TEST_DELAY_SECONDS=${POST_BUILD_TEST_DELAY_SECONDS:-"3"}
  POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS=${POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS:-"5"}
  POST_BUILD_TEST_MAX_TIME_SECONDS=${POST_BUILD_TEST_MAX_TIME_SECONDS:-"15"}
  DRY_RUN=${DRY_RUN:-"0"}
  DOCKER_USE_SUDO=${DOCKER_USE_SUDO:-"0"}
}

docker_probe() {
  if [ "$DOCKER_USE_SUDO" = "1" ]; then
    run_with_optional_sudo docker "$@"
    return $?
  fi

  docker "$@"
}

docker_run() {
  if [ "$DOCKER_USE_SUDO" = "1" ]; then
    run_with_optional_sudo docker "$@"
    return 0
  fi

  run_cmd docker "$@"
}

validate_access_mode() {
  case "$OPENCLAW_ACCESS_MODE" in
    ssh-tunnel)
      OPENCLAW_COMPOSE_TEMPLATE=${OPENCLAW_COMPOSE_TEMPLATE:-"$OPENCLAW_COMPOSE_TEMPLATE_SSH_TUNNEL"}
      OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-"http://127.0.0.1:18789"}
      ;;
    public)
      OPENCLAW_COMPOSE_TEMPLATE=${OPENCLAW_COMPOSE_TEMPLATE:-"$OPENCLAW_COMPOSE_TEMPLATE_PUBLIC"}
      public_domain=${OPENCLAW_DOMAIN:-""}
      OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-"https://$public_domain"}
      ;;
    *)
      fail "OPENCLAW_ACCESS_MODE must be either 'ssh-tunnel' or 'public'"
      ;;
  esac

}

require_public_env_if_needed() {
  if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
    require_env TRAEFIK_ACME_EMAIL
    require_env OPENCLAW_DOMAIN
  fi
}

check_docker_access() {
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN=1 enabled; no system or Docker changes will be applied"
    return 0
  fi

  require_command git
  ensure_docker_available
  if [ "$POST_BUILD_TEST" != "0" ]; then
    require_command curl
  fi
  if ! docker compose version > /dev/null 2>&1; then
    run_with_optional_sudo docker compose version > /dev/null 2>&1 || fail "docker compose is required"
    DOCKER_USE_SUDO=1
    log "Using sudo for Docker commands in this run"
  fi

  log "Checking Docker access"
  if ! docker ps > /dev/null 2>&1; then
    if [ "$SKIP_DOCKER_GROUP_SETUP" = "1" ]; then
      if run_with_optional_sudo docker ps > /dev/null 2>&1; then
        DOCKER_USE_SUDO=1
        log "docker ps failed without sudo; continuing with sudo (SKIP_DOCKER_GROUP_SETUP=1)"
        return 0
      fi
      fail "docker ps failed and SKIP_DOCKER_GROUP_SETUP=1"
    fi

    log "Adding $CURRENT_USER to the docker group"
    run_with_optional_sudo usermod -aG docker "$CURRENT_USER"
    if run_with_optional_sudo docker ps > /dev/null 2>&1; then
      DOCKER_USE_SUDO=1
      log "Docker group updated; continuing this run with sudo. Reconnect later to use docker without sudo."
      return 0
    fi
    fail "Docker permissions updated, but docker access still unavailable. Reconnect or run 'newgrp docker', then rerun the script."
  fi
}

ensure_docker_available() {
  if command -v docker > /dev/null 2>&1; then
    return 0
  fi

  install_docker_on_host
  require_command docker
}

install_docker_on_host() {
  log "Docker is missing; installing Docker and docker compose on host"
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] sudo sh -c \"curl -fsSL https://get.docker.com | sh\""
    return 0
  fi

  require_command curl
  require_command sh
  run_with_optional_sudo sh -c "curl -fsSL https://get.docker.com | sh"
}

setup_access_mode_prerequisites() {
  if [ "$OPENCLAW_ACCESS_MODE" != "public" ]; then
    log "Access mode is ssh-tunnel; skipping Traefik and proxy network setup"
    return 0
  fi

  ensure_proxy_network
  write_traefik_config
  start_traefik
}

ensure_proxy_network() {
  log "Creating shared Docker network"
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] docker network inspect proxy"
    log "[DRY_RUN] docker network create proxy"
  elif ! docker_probe network inspect proxy > /dev/null 2>&1; then
    docker_run network create proxy > /dev/null
  fi
}

write_traefik_config() {
  log "Writing Traefik configuration into $TRAEFIK_DIR"
  run_cmd mkdir -p "$TRAEFIK_DIR/letsencrypt"
  run_cmd chmod 700 "$TRAEFIK_DIR/letsencrypt"
  run_cmd touch "$TRAEFIK_DIR/letsencrypt/acme.json"
  run_cmd chmod 600 "$TRAEFIK_DIR/letsencrypt/acme.json"
  render_template "$TRAEFIK_DIR/docker-compose.yml" "$TRAEFIK_COMPOSE_TEMPLATE"
}

start_traefik() {
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] (cd $TRAEFIK_DIR && docker compose up -d)"
    return 0
  fi

  (
    cd "$TRAEFIK_DIR"
    log "Starting Traefik"
    docker_run compose up -d
  )
}

prepare_openclaw_repo() {
  log "Preparing OpenClaw repository in $OPENCLAW_DIR"
  if [ -d "$OPENCLAW_DIR/.git" ]; then
    (
      cd "$OPENCLAW_DIR"
      run_cmd git pull --ff-only
    )
  else
    run_cmd git clone "$OPENCLAW_REPO" "$OPENCLAW_DIR"
  fi

  run_cmd mkdir -p "$OPENCLAW_CONFIG_DIR"
  run_cmd mkdir -p "$OPENCLAW_WORKSPACE_DIR"
  if [ "$DRY_RUN" != "1" ]; then
    ensure_safe_chown_path "$OPENCLAW_DIR"
    ensure_safe_chown_path "$OPENCLAW_CONFIG_DIR"
  fi
  run_with_optional_sudo chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_DIR" "$OPENCLAW_CONFIG_DIR"
}

run_openclaw_wizard_if_needed() {
  if [ ! -f "$OPENCLAW_DIR/.env" ]; then
    log "Running OpenClaw's docker setup wizard"
    if [ "$DRY_RUN" = "1" ]; then
      log "[DRY_RUN] (cd $OPENCLAW_DIR && ./docker-setup.sh)"
    else
      (
        cd "$OPENCLAW_DIR"
        ./docker-setup.sh
      )
    fi
  fi

  if [ "$DRY_RUN" != "1" ]; then
    [ -f "$OPENCLAW_DIR/.env" ] || fail "OpenClaw .env not found in $OPENCLAW_DIR. Run ./docker-setup.sh first."
  fi
}

resolve_openclaw_token() {
  if [ -z "${OPENCLAW_TOKEN:-}" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      OPENCLAW_TOKEN="dry-run-token"
    else
      OPENCLAW_TOKEN=$(extract_openclaw_token "$OPENCLAW_DIR/.env" || true)
    fi
  fi
  [ -n "${OPENCLAW_TOKEN:-}" ] || fail "Unable to determine OPENCLAW_TOKEN from $OPENCLAW_DIR/.env"
}

write_openclaw_compose() {
  log "Writing OpenClaw docker-compose.yml"
  render_template "$OPENCLAW_DIR/docker-compose.yml" "$OPENCLAW_COMPOSE_TEMPLATE"
}

ensure_openclaw_env_overrides() {
  log "Ensuring OpenClaw .env contains local path overrides"
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] append OPENCLAW_CONFIG_DIR to $OPENCLAW_DIR/.env when missing"
    log "[DRY_RUN] append OPENCLAW_WORKSPACE_DIR to $OPENCLAW_DIR/.env when missing"
    return 0
  fi

  if ! grep -q '^OPENCLAW_CONFIG_DIR=' "$OPENCLAW_DIR/.env"; then
    printf '\nOPENCLAW_CONFIG_DIR=%s\n' "$OPENCLAW_CONFIG_DIR" >> "$OPENCLAW_DIR/.env"
  fi
  if ! grep -q '^OPENCLAW_WORKSPACE_DIR=' "$OPENCLAW_DIR/.env"; then
    printf 'OPENCLAW_WORKSPACE_DIR=%s\n' "$OPENCLAW_WORKSPACE_DIR" >> "$OPENCLAW_DIR/.env"
  fi
}

write_openclaw_json_config() {
  OPENCLAW_JSON="$OPENCLAW_CONFIG_DIR/openclaw.json"
  if [ -f "$OPENCLAW_JSON" ]; then
    OPENCLAW_JSON_BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    OPENCLAW_JSON_BACKUP_FILE="$OPENCLAW_JSON_BACKUP_DIR/openclaw.json.$OPENCLAW_JSON_BACKUP_TIMESTAMP.bak"
    run_cmd mkdir -p "$OPENCLAW_JSON_BACKUP_DIR"
    run_cmd chmod 700 "$OPENCLAW_JSON_BACKUP_DIR"
    run_cmd cp "$OPENCLAW_JSON" "$OPENCLAW_JSON_BACKUP_FILE"
    run_cmd chmod 600 "$OPENCLAW_JSON_BACKUP_FILE"
  fi

  log "Writing $OPENCLAW_JSON"
  run_cmd mkdir -p "$OPENCLAW_CONFIG_DIR"
  run_cmd chmod 700 "$OPENCLAW_CONFIG_DIR"
  render_template "$OPENCLAW_JSON" "$OPENCLAW_JSON_TEMPLATE"
  run_cmd chmod 600 "$OPENCLAW_JSON"

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] validate rendered OpenClaw JSON: $OPENCLAW_JSON"
    return 0
  fi

  require_command python3
  python3 -m json.tool "$OPENCLAW_JSON" > /dev/null || fail "Rendered OpenClaw JSON is invalid: $OPENCLAW_JSON"
}

ensure_openclaw_image() {
  log "Pulling OpenClaw official image: $OPENCLAW_IMAGE"
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] docker pull $OPENCLAW_IMAGE"
    return 0
  fi

  docker_run pull "$OPENCLAW_IMAGE"
}

restart_openclaw() {
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] (cd $OPENCLAW_DIR && docker compose down && docker compose up -d)"
    return 0
  fi

  (
    cd "$OPENCLAW_DIR"
    log "Restarting OpenClaw"
    docker_run compose down
    docker_run compose up -d
  )
}

post_build_connectivity_test() {
  if [ "$POST_BUILD_TEST" = "0" ]; then
    log "Skipping post-build connectivity validation (POST_BUILD_TEST=0)"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
      log "[DRY_RUN] validate https://$OPENCLAW_DOMAIN with curl (${POST_BUILD_TEST_ATTEMPTS} attempts, connect-timeout=${POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS}s, max-time=${POST_BUILD_TEST_MAX_TIME_SECONDS}s)"
    else
      log "[DRY_RUN] validate http://127.0.0.1:18789/healthz with curl (${POST_BUILD_TEST_ATTEMPTS} attempts, connect-timeout=${POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS}s, max-time=${POST_BUILD_TEST_MAX_TIME_SECONDS}s)"
    fi
    return 0
  fi

  require_command curl
  attempts_left=$POST_BUILD_TEST_ATTEMPTS
  [ "$attempts_left" -gt 0 ] 2> /dev/null || fail "POST_BUILD_TEST_ATTEMPTS must be a positive integer"
  [ "$POST_BUILD_TEST_DELAY_SECONDS" -ge 0 ] 2> /dev/null || fail "POST_BUILD_TEST_DELAY_SECONDS must be an integer >= 0"
  [ "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" -gt 0 ] 2> /dev/null || fail "POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS must be a positive integer"
  [ "$POST_BUILD_TEST_MAX_TIME_SECONDS" -gt 0 ] 2> /dev/null || fail "POST_BUILD_TEST_MAX_TIME_SECONDS must be a positive integer"
  [ "$POST_BUILD_TEST_MAX_TIME_SECONDS" -ge "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" ] 2> /dev/null || fail "POST_BUILD_TEST_MAX_TIME_SECONDS must be >= POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS"

  if [ "$OPENCLAW_ACCESS_MODE" = "ssh-tunnel" ]; then
    validate_ssh_tunnel_mode
    return 0
  fi

  validate_public_mode
}

validate_ssh_tunnel_mode() {
  log "Validating local OpenClaw health endpoint for ssh-tunnel mode"
  attempts_left=$POST_BUILD_TEST_ATTEMPTS

  while [ "$attempts_left" -gt 0 ]; do
    if curl --fail --silent --show-error --location \
      --connect-timeout "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" \
      --max-time "$POST_BUILD_TEST_MAX_TIME_SECONDS" \
      "http://127.0.0.1:18789/healthz" > /dev/null; then
      log "Post-build local health validation passed"
      return 0
    fi

    attempts_left=$((attempts_left - 1))
    [ "$attempts_left" -gt 0 ] || break
    sleep "$POST_BUILD_TEST_DELAY_SECONDS"
  done

  fail "Local health validation failed for http://127.0.0.1:18789/healthz after ${POST_BUILD_TEST_ATTEMPTS} attempts"
}

validate_public_mode() {
  log "Validating TLS/connectivity for https://$OPENCLAW_DOMAIN"
  attempts_left=$POST_BUILD_TEST_ATTEMPTS

  while [ "$attempts_left" -gt 0 ]; do
    probe_file=$(mktemp)
    if http_code=$(curl --silent --show-error --location --output /dev/null --write-out '%{http_code}' \
      --connect-timeout "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" \
      --max-time "$POST_BUILD_TEST_MAX_TIME_SECONDS" \
      "https://$OPENCLAW_DOMAIN" 2> "$probe_file"); then
      rm -f "$probe_file"
      case "$http_code" in
        2* | 3* | 4*)
          log "Post-build public TLS/connectivity validation passed (HTTP $http_code)"
          return 0
          ;;
      esac
    else
      probe_error=$(cat "$probe_file")
      rm -f "$probe_file"
      case "$probe_error" in
        *self-signed* | *certificate* | *SSL* | *TLS*)
          log "TLS is not ready yet (retrying): $probe_error"
          ;;
        *)
          log "Connectivity probe failed (retrying): $probe_error"
          ;;
      esac
    fi

    attempts_left=$((attempts_left - 1))
    [ "$attempts_left" -gt 0 ] || break
    sleep "$POST_BUILD_TEST_DELAY_SECONDS"
  done

  fail "Public TLS/connectivity validation failed for https://$OPENCLAW_DOMAIN after ${POST_BUILD_TEST_ATTEMPTS} attempts"
}

print_summary() {
  log "OpenClaw deployment finished"
  log "Access mode: $OPENCLAW_ACCESS_MODE"
  if [ "$OPENCLAW_ACCESS_MODE" = "public" ]; then
    log "URL: https://${OPENCLAW_DOMAIN}"
  else
    log "SSH tunnel: ssh -N -L 18789:127.0.0.1:18789 <user>@<host>"
    log "Local URL after tunnel: http://127.0.0.1:18789"
  fi
  log "Gateway token: <redacted>"
  log "Container logs: docker logs openclaw"
  log "Pending device approvals: docker exec -it openclaw node dist/index.js devices list"
}
