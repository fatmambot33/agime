#!/usr/bin/env sh

set -eu

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=scripts/build_lib.sh
. "$SCRIPT_DIR/scripts/build_lib.sh"
# shellcheck source=scripts/build_steps.sh
. "$SCRIPT_DIR/scripts/build_steps.sh"

usage() {
  cat << EOF2
Usage:
 OPENCLAW_ACCESS_MODE=ssh-tunnel \\
 OVH_ENDPOINT_API_KEY=xxxxx \\
 sh $SCRIPT_NAME

For public mode, also set:
 TRAEFIK_ACME_EMAIL=admin@example.com
 OPENCLAW_DOMAIN=openclaw.example.com

Required environment variables:
 OPENCLAW_ACCESS_MODE One of: ssh-tunnel (default) or public.
 OVH_ENDPOINT_API_KEY OVHcloud AI Endpoints API key.

Public mode required variables:
 TRAEFIK_ACME_EMAIL Email used by Let's Encrypt / Traefik.
 OPENCLAW_DOMAIN Public domain that points to the VPS.

Optional environment variables:
 OPENCLAW_TOKEN Reuse an existing OpenClaw gateway token.
 OPENCLAW_DIR Default: \$HOME/openclaw
 OPENCLAW_CONFIG_DIR Default: \$HOME/.openclaw
 OPENCLAW_WORKSPACE_DIR Default: \$HOME/.openclaw/workspace
 OPENCLAW_JSON_BACKUP_DIR Default: \$HOME/openclaw-backups. Stores timestamped openclaw.json backups.
 TRAEFIK_DIR Default: \$HOME/docker/traefik
 OPENCLAW_REPO Default: https://github.com/openclaw/openclaw.git
 OPENCLAW_IMAGE Default: openclaw:local
 OPENCLAW_GATEWAY_BIND Default: lan (public mode template only)
 OVH_ENDPOINT_BASE_URL Default: https://oai.endpoints.kepler.ai.cloud.ovh.net/v1
 OVH_ENDPOINT_MODEL Default: gpt-oss-120b
 OPENCLAW_USER Default: current user
 TRAEFIK_COMPOSE_TEMPLATE Optional template path. Default: \$SCRIPT_DIR/templates/traefik-compose.yml.tmpl
 OPENCLAW_COMPOSE_TEMPLATE Optional template path. Defaults by mode:
   - ssh-tunnel: \$SCRIPT_DIR/templates/openclaw-compose.ssh-tunnel.yml.tmpl
   - public: \$SCRIPT_DIR/templates/openclaw-compose.public.yml.tmpl
 OPENCLAW_JSON_TEMPLATE Optional template path. Default: \$SCRIPT_DIR/templates/openclaw.json.tmpl
 SKIP_DOCKER_GROUP_SETUP Default: 0. Set to 1 to skip docker group changes.
 SKIP_OPENCLAW_WIZARD Default: 0. Set to 1 to forbid wizard fallback when bootstrap cannot write .env.
 SKIP_OPENCLAW_IMAGE_BUILD Default: 0. Set to 1 to skip rebuilding local OpenClaw image.
 POST_BUILD_TEST Default: 1. Set to 0 to skip post-build connectivity validation.
 POST_BUILD_TEST_ATTEMPTS Default: 40. Number of validation attempts.
 POST_BUILD_TEST_DELAY_SECONDS Default: 3. Delay between validation attempts.
 POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS Default: 5. curl connect timeout per probe.
 POST_BUILD_TEST_MAX_TIME_SECONDS Default: 15. curl total timeout per probe.
 DRY_RUN Default: 0. Set to 1 to print planned actions without applying changes.

Notes:
 - This script automates the OVHcloud guide published on 2026-02-25:
 https://help.ovhcloud.com/csm/fr-vps-install-openclaw?id=kb_article_view&sysparm_article=KB0074788
 - Docker and Docker Compose must already be installed.
 - On first run, agime attempts a non-interactive .env bootstrap.
 - If bootstrap cannot run, agime falls back to OpenClaw's interactive wizard unless SKIP_OPENCLAW_WIZARD=1.
EOF2
}

[ "${1-}" = "--help" ] && {
  usage
  exit 0
}

initialize_defaults
validate_access_mode
require_env OVH_ENDPOINT_API_KEY
require_public_env_if_needed
check_docker_access
setup_access_mode_prerequisites
prepare_openclaw_repo
run_openclaw_wizard_if_needed
resolve_openclaw_token
write_openclaw_compose
ensure_openclaw_env_overrides
write_openclaw_json_config
ensure_openclaw_image
restart_openclaw
post_build_connectivity_test
print_summary
