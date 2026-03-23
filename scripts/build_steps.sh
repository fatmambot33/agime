#!/usr/bin/env sh
# shellcheck shell=sh
# shellcheck disable=SC2154

initialize_defaults() {
  CURRENT_USER=$(id -un)
  HOME_DIR=${HOME:-"$(getent passwd "$CURRENT_USER" | cut -d : -f 6 2> /dev/null || printf '/home/%s' "$CURRENT_USER")"}
  OPENCLAW_DIR=${OPENCLAW_DIR:-"$HOME_DIR/openclaw"}
  OPENCLAW_CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-"$HOME_DIR/.openclaw"}
  OPENCLAW_WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR:-"$OPENCLAW_CONFIG_DIR/workspace"}
  TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME_DIR/docker/traefik"}
  OPENCLAW_REPO=${OPENCLAW_REPO:-"https://github.com/openclaw/openclaw.git"}
  OPENCLAW_IMAGE=${OPENCLAW_IMAGE:-"openclaw:local"}
  OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-"lan"}
  OVH_ENDPOINT_BASE_URL=${OVH_ENDPOINT_BASE_URL:-"https://oai.endpoints.kepler.ai.cloud.ovh.net/v1"}
  OVH_ENDPOINT_MODEL=${OVH_ENDPOINT_MODEL:-"gpt-oss-120b"}
  OPENCLAW_USER=${OPENCLAW_USER:-"$CURRENT_USER"}
  TRAEFIK_COMPOSE_TEMPLATE=${TRAEFIK_COMPOSE_TEMPLATE:-"$SCRIPT_DIR/templates/traefik-compose.yml.tmpl"}
  OPENCLAW_COMPOSE_TEMPLATE=${OPENCLAW_COMPOSE_TEMPLATE:-"$SCRIPT_DIR/templates/openclaw-compose.yml.tmpl"}
  OPENCLAW_JSON_TEMPLATE=${OPENCLAW_JSON_TEMPLATE:-"$SCRIPT_DIR/templates/openclaw.json.tmpl"}
  SKIP_DOCKER_GROUP_SETUP=${SKIP_DOCKER_GROUP_SETUP:-"0"}
  SKIP_OPENCLAW_WIZARD=${SKIP_OPENCLAW_WIZARD:-"0"}
  POST_BUILD_TEST=${POST_BUILD_TEST:-"1"}
  POST_BUILD_TEST_ATTEMPTS=${POST_BUILD_TEST_ATTEMPTS:-"20"}
  POST_BUILD_TEST_DELAY_SECONDS=${POST_BUILD_TEST_DELAY_SECONDS:-"3"}
  POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS=${POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS:-"5"}
  POST_BUILD_TEST_MAX_TIME_SECONDS=${POST_BUILD_TEST_MAX_TIME_SECONDS:-"15"}
  OPENCLAW_ALLOWED_ORIGIN=${OPENCLAW_ALLOWED_ORIGIN:-"https://$OPENCLAW_DOMAIN"}
  DRY_RUN=${DRY_RUN:-"0"}
}

check_docker_access() {
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN=1 enabled; no system or Docker changes will be applied"
    return 0
  fi

  require_command docker
  require_command git
  if [ "$POST_BUILD_TEST" != "0" ]; then
    require_command curl
  fi
  docker compose version > /dev/null 2>&1 || fail "docker compose is required"

  log "Checking Docker access"
  if ! docker ps > /dev/null 2>&1; then
    if [ "$SKIP_DOCKER_GROUP_SETUP" = "1" ]; then
      fail "docker ps failed and SKIP_DOCKER_GROUP_SETUP=1"
    fi

    log "Adding $CURRENT_USER to the docker group"
    sudo usermod -aG docker "$CURRENT_USER"
    fail "Docker permissions updated. Reconnect or run 'newgrp docker', then rerun the script."
  fi
}

ensure_proxy_network() {
  log "Creating shared Docker network"
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] docker network inspect proxy"
    log "[DRY_RUN] docker network create proxy"
  elif ! docker network inspect proxy > /dev/null 2>&1; then
    run_cmd docker network create proxy > /dev/null
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
    run_cmd docker compose up -d
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

  run_cmd mkdir -p "$OPENCLAW_WORKSPACE_DIR"
  if [ "$DRY_RUN" != "1" ]; then
    ensure_safe_chown_path "$OPENCLAW_DIR"
    ensure_safe_chown_path "$OPENCLAW_CONFIG_DIR"
  fi
  run_cmd sudo chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_DIR" "$OPENCLAW_CONFIG_DIR"
}

run_openclaw_wizard_if_needed() {
  if [ ! -f "$OPENCLAW_DIR/.env" ] && [ "$SKIP_OPENCLAW_WIZARD" != "1" ]; then
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
    run_cmd cp "$OPENCLAW_JSON" "${OPENCLAW_JSON}.bak"
    run_cmd chmod 600 "${OPENCLAW_JSON}.bak"
  fi

  log "Writing $OPENCLAW_JSON"
  run_cmd mkdir -p "$OPENCLAW_CONFIG_DIR"
  run_cmd chmod 700 "$OPENCLAW_CONFIG_DIR"
  render_template "$OPENCLAW_JSON" "$OPENCLAW_JSON_TEMPLATE"
  run_cmd chmod 600 "$OPENCLAW_JSON"
}

restart_openclaw() {
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] (cd $OPENCLAW_DIR && docker compose down && docker compose up -d)"
    return 0
  fi

  (
    cd "$OPENCLAW_DIR"
    log "Restarting OpenClaw"
    run_cmd docker compose down
    run_cmd docker compose up -d
  )
}

post_build_tls_test() {
  if [ "$POST_BUILD_TEST" = "0" ]; then
    log "Skipping post-build HTTPS/TLS validation (POST_BUILD_TEST=0)"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY_RUN] validate https://$OPENCLAW_DOMAIN with curl (${POST_BUILD_TEST_ATTEMPTS} attempts, connect-timeout=${POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS}s, max-time=${POST_BUILD_TEST_MAX_TIME_SECONDS}s)"
    return 0
  fi

  require_command curl
  attempts_left=$POST_BUILD_TEST_ATTEMPTS
  [ "$attempts_left" -gt 0 ] 2> /dev/null || fail "POST_BUILD_TEST_ATTEMPTS must be a positive integer"
  [ "$POST_BUILD_TEST_DELAY_SECONDS" -ge 0 ] 2> /dev/null || fail "POST_BUILD_TEST_DELAY_SECONDS must be an integer >= 0"
  [ "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" -gt 0 ] 2> /dev/null || fail "POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS must be a positive integer"
  [ "$POST_BUILD_TEST_MAX_TIME_SECONDS" -gt 0 ] 2> /dev/null || fail "POST_BUILD_TEST_MAX_TIME_SECONDS must be a positive integer"
  [ "$POST_BUILD_TEST_MAX_TIME_SECONDS" -ge "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" ] 2> /dev/null || fail "POST_BUILD_TEST_MAX_TIME_SECONDS must be >= POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS"

  log "Validating HTTPS/TLS availability for https://$OPENCLAW_DOMAIN"
  while [ "$attempts_left" -gt 0 ]; do
    if curl --fail --silent --show-error --location \
      --connect-timeout "$POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS" \
      --max-time "$POST_BUILD_TEST_MAX_TIME_SECONDS" \
      "https://$OPENCLAW_DOMAIN" > /dev/null; then
      log "Post-build HTTPS/TLS validation passed"
      return 0
    fi

    attempts_left=$((attempts_left - 1))
    [ "$attempts_left" -gt 0 ] || break
    sleep "$POST_BUILD_TEST_DELAY_SECONDS"
  done

  fail "HTTPS/TLS validation failed for https://$OPENCLAW_DOMAIN after ${POST_BUILD_TEST_ATTEMPTS} attempts"
}

print_summary() {
  log "OpenClaw deployment finished"
  log "URL: https://${OPENCLAW_DOMAIN}"
  log "Gateway token: <redacted>"
  log "Container logs: docker logs openclaw"
  log "Pending device approvals: docker exec -it openclaw node dist/index.js devices list"
}
