#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_FILE=$(mktemp)
trap 'rm -f "$OUTPUT_FILE"' EXIT

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
