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
 OPENCLAW_ENABLE_SIGNAL Default: 0. Set to 1 to enable Signal channel setup.
 OPENCLAW_SIGNAL_ACCOUNT Required when OPENCLAW_ENABLE_SIGNAL=1. Signal account number in E.164 format.
 OPENCLAW_SIGNAL_ALLOW_FROM Optional DM allowlist sender (single E.164 or uuid:<id> entry).
 OPENCLAW_SIGNAL_CLI_PATH Default: signal-cli. Path/command used by OpenClaw for Signal.
 OPENCLAW_SIGNAL_AUTO_INSTALL Default: 1. Set to 0 to disable automatic signal-cli installation.
 OPENCLAW_ENABLE_GITHUB_SKILL Default: 0. Set to 1 to validate/install GitHub CLI (gh) for GitHub skill usage.
 OPENCLAW_GH_CLI_PATH Default: gh. Path/command used to invoke GitHub CLI.
 OPENCLAW_ENABLE_HIMALAYA_SKILL Default: 0. Set to 1 to validate/install Himalaya CLI for Himalaya skill usage.
 OPENCLAW_HIMALAYA_CLI_PATH Default: himalaya. Path/command used to invoke Himalaya CLI.
 OPENCLAW_HIMALAYA_REQUIRE_CONFIG Default: 1. Set to 0 to skip config file validation.
 OPENCLAW_HIMALAYA_CONFIG_PATH Default: \$OPENCLAW_CONFIG_DIR/himalaya/config.toml
 OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64 Optional base64-encoded Himalaya config.toml content to render at OPENCLAW_HIMALAYA_CONFIG_PATH.
 OPENCLAW_ENABLE_CODING_AGENT_SKILL Default: 0. Set to 1 to validate/install coding-agent backend CLI.
 OPENCLAW_CODING_AGENT_BACKEND Default: codex. One of: claude, codex, opencode, pi.
 SKIP_DOCKER_GROUP_SETUP Default: 0. Set to 1 to skip docker group changes.
 SKIP_OPENCLAW_WIZARD Default: 0. Set to 1 if .env already exists.
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
 - If OPENCLAW_ENABLE_GITHUB_SKILL=1, this script can auto-install GitHub CLI (gh) when missing
   (apt-get only) and validates runtime binary visibility in the container.
 - Authenticate manually in-container as needed for your workflow.
 - If OPENCLAW_ENABLE_HIMALAYA_SKILL=1, this script can auto-install Himalaya CLI (himalaya) when missing
   (apt-get only), can write config from OPENCLAW_HIMALAYA_CONFIG_TOML_BASE64, and by default requires config
   at \$HOME/.config/himalaya/config.toml.
 - If config is missing, run: himalaya account configure and rerun the script.
 - If OPENCLAW_ENABLE_CODING_AGENT_SKILL=1, this script validates/install coding-agent backend CLIs:
   - claude => npm i -g @anthropic-ai/claude-code
   - codex => npm i -g @openai/codex
   - pi => npm i -g @mariozechner/pi-coding-agent
   - opencode must be installed manually
   and validates runtime binary visibility in the container.
   and validates <backend> --version inside the running container runtime.
 - If the OpenClaw setup wizard runs, it remains interactive.
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
setup_signal_channel_prerequisites
setup_github_skill_prerequisites
setup_himalaya_skill_prerequisites
setup_coding_agent_skill_prerequisites
setup_access_mode_prerequisites
prepare_openclaw_repo
run_openclaw_wizard_if_needed
resolve_openclaw_token
write_openclaw_compose
ensure_openclaw_env_overrides
write_openclaw_json_config
ensure_openclaw_image
restart_openclaw
install_optional_skill_container_runtime_dependencies
validate_optional_skill_container_runtime
post_build_connectivity_test
print_summary
