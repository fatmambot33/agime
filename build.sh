#!/usr/bin/env sh

set -eu

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

. "$SCRIPT_DIR/scripts/build_lib.sh"
. "$SCRIPT_DIR/scripts/build_steps.sh"

usage() {
  cat <<EOF2
Usage:
 TRAEFIK_ACME_EMAIL=admin@example.com \\
 OPENCLAW_DOMAIN=openclaw.example.com \\
 OVH_ENDPOINT_API_KEY=xxxxx \\
 sh $SCRIPT_NAME

Required environment variables:
 TRAEFIK_ACME_EMAIL Email used by Let's Encrypt / Traefik.
 OPENCLAW_DOMAIN Public domain that points to the VPS.
 OVH_ENDPOINT_API_KEY OVHcloud AI Endpoints API key.

Optional environment variables:
 OPENCLAW_TOKEN Reuse an existing OpenClaw gateway token.
 OPENCLAW_DIR Default: \$HOME/openclaw
 OPENCLAW_CONFIG_DIR Default: \$HOME/.openclaw
 OPENCLAW_WORKSPACE_DIR Default: \$HOME/.openclaw/workspace
 TRAEFIK_DIR Default: \$HOME/docker/traefik
 OPENCLAW_REPO Default: https://github.com/openclaw/openclaw.git
 OPENCLAW_IMAGE Default: openclaw:local
 OPENCLAW_GATEWAY_BIND Default: lan
 OVH_ENDPOINT_BASE_URL Default: https://oai.endpoints.kepler.ai.cloud.ovh.net/v1
 OVH_ENDPOINT_MODEL Default: gpt-oss-120b
 OPENCLAW_USER Default: current user
 TRAEFIK_COMPOSE_TEMPLATE Optional template path. Default: \$SCRIPT_DIR/templates/traefik-compose.yml.tmpl
 OPENCLAW_COMPOSE_TEMPLATE Optional template path. Default: \$SCRIPT_DIR/templates/openclaw-compose.yml.tmpl
 OPENCLAW_JSON_TEMPLATE Optional template path. Default: \$SCRIPT_DIR/templates/openclaw.json.tmpl
 SKIP_DOCKER_GROUP_SETUP Default: 0. Set to 1 to skip docker group changes.
 SKIP_OPENCLAW_WIZARD Default: 0. Set to 1 if .env already exists.
 DRY_RUN Default: 0. Set to 1 to print planned actions without applying changes.

Notes:
 - This script automates the OVHcloud guide published on 2026-02-25:
 https://help.ovhcloud.com/csm/fr-vps-install-openclaw?id=kb_article_view&sysparm_article=KB0074788
 - Docker and Docker Compose must already be installed.
 - If the OpenClaw setup wizard runs, it remains interactive.
EOF2
}

[ "${1-}" = "--help" ] && {
  usage
  exit 0
}

require_env TRAEFIK_ACME_EMAIL
require_env OPENCLAW_DOMAIN
require_env OVH_ENDPOINT_API_KEY

initialize_defaults
check_docker_access
ensure_proxy_network
write_traefik_config
start_traefik
prepare_openclaw_repo
run_openclaw_wizard_if_needed
resolve_openclaw_token
write_openclaw_compose
ensure_openclaw_env_overrides
write_openclaw_json_config
restart_openclaw
print_summary
