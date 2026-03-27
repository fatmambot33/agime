#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_FILE=$(mktemp)
OUTPUT_SIGNAL_FILE=$(mktemp)
OUTPUT_SKILLS_FILE=$(mktemp)
trap 'rm -f "$OUTPUT_FILE" "$OUTPUT_SIGNAL_FILE" "$OUTPUT_SKILLS_FILE"' EXIT

(
  cd "$SCRIPT_DIR"
  DRY_RUN=1 \
    OVH_ENDPOINT_API_KEY=dummy-key \
    sh ./build.sh > "$OUTPUT_FILE"
)

grep -q 'DRY_RUN=1 enabled; no system or Docker changes will be applied' "$OUTPUT_FILE"
grep -q 'Access mode is ssh-tunnel; skipping Traefik and proxy network setup' "$OUTPUT_FILE"
grep -q 'render .*openclaw-compose.ssh-tunnel.yml.tmpl' "$OUTPUT_FILE"
grep -q 'render .*openclaw.json.tmpl' "$OUTPUT_FILE"
grep -q 'OpenClaw deployment finished' "$OUTPUT_FILE"
grep -q 'Access mode: ssh-tunnel' "$OUTPUT_FILE"
grep -q 'Gateway token: <redacted>' "$OUTPUT_FILE"
if grep -q 'Gateway token: dry-run-token' "$OUTPUT_FILE"; then
  echo "Gateway token leaked in output" >&2
  exit 1
fi

echo "DRY_RUN smoke test passed"

(
  cd "$SCRIPT_DIR"
  DRY_RUN=1 \
    OVH_ENDPOINT_API_KEY=dummy-key \
    OPENCLAW_ENABLE_SIGNAL=1 \
    OPENCLAW_SIGNAL_ACCOUNT=+15551234567 \
    OPENCLAW_SIGNAL_CLI_PATH=signal-cli-custom \
    sh ./build.sh > "$OUTPUT_SIGNAL_FILE"
)

grep -q 'Signal channel enabled; runtime dependency will be validated inside Docker container after restart' "$OUTPUT_SIGNAL_FILE"
grep -q '\[DRY_RUN\] validate Signal channel prerequisites runtime binary inside openclaw container: signal-cli-custom' "$OUTPUT_SIGNAL_FILE"
grep -q '\[DRY_RUN\] validate Signal channel prerequisites runtime command inside openclaw container: signal-cli-custom --version' "$OUTPUT_SIGNAL_FILE"
grep -q 'OpenClaw deployment finished' "$OUTPUT_SIGNAL_FILE"

echo "DRY_RUN signal smoke test passed"

(
  cd "$SCRIPT_DIR"
  DRY_RUN=1 \
    OVH_ENDPOINT_API_KEY=dummy-key \
    OPENCLAW_ENABLE_GITHUB_SKILL=1 \
    OPENCLAW_ENABLE_HIMALAYA_SKILL=1 \
    OPENCLAW_ENABLE_CODING_AGENT_SKILL=1 \
    OPENCLAW_HIMALAYA_REQUIRE_CONFIG=0 \
    sh ./build.sh > "$OUTPUT_SKILLS_FILE"
)

grep -q '\[DRY_RUN\] validate GitHub skill prerequisites runtime binary inside openclaw container: gh' "$OUTPUT_SKILLS_FILE"
grep -q '\[DRY_RUN\] validate GitHub skill prerequisites runtime command inside openclaw container: gh --version' "$OUTPUT_SKILLS_FILE"
grep -q "GitHub skill follow-up: authenticate inside the running container before using GitHub skill actions" "$OUTPUT_SKILLS_FILE"
grep -q "docker exec openclaw sh -lc 'gh auth login'" "$OUTPUT_SKILLS_FILE"
grep -q '\[DRY_RUN\] validate Himalaya skill prerequisites runtime binary inside openclaw container: himalaya' "$OUTPUT_SKILLS_FILE"
grep -q '\[DRY_RUN\] validate Himalaya skill prerequisites runtime command inside openclaw container: himalaya --version' "$OUTPUT_SKILLS_FILE"
grep -q '\[DRY_RUN\] validate coding-agent skill prerequisites runtime binary inside openclaw container: codex' "$OUTPUT_SKILLS_FILE"
grep -q '\[DRY_RUN\] validate coding-agent skill prerequisites (codex sandbox runtime) runtime binary inside openclaw container: bwrap' "$OUTPUT_SKILLS_FILE"
grep -q '\[DRY_RUN\] validate coding-agent skill prerequisites runtime command inside openclaw container: codex --version' "$OUTPUT_SKILLS_FILE"
grep -q 'OpenClaw deployment finished' "$OUTPUT_SKILLS_FILE"

echo "DRY_RUN optional-skill runtime smoke test passed"
