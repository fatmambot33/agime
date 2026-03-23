#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_ONE=$(mktemp)
OUTPUT_TWO=$(mktemp)
trap 'rm -f "$OUTPUT_ONE" "$OUTPUT_TWO"' EXIT

run_dry_run() {
  output_file=$1
  (
    cd "$SCRIPT_DIR"
    DRY_RUN=1 \
      TRAEFIK_ACME_EMAIL=admin@example.com \
      OPENCLAW_DOMAIN=openclaw.example.com \
      OVH_ENDPOINT_API_KEY=dummy-key \
      sh ./build.sh > "$output_file"
  )
}

run_dry_run "$OUTPUT_ONE"
run_dry_run "$OUTPUT_TWO"

cmp -s "$OUTPUT_ONE" "$OUTPUT_TWO"

grep -q 'DRY_RUN=1 enabled; no system or Docker changes will be applied' "$OUTPUT_ONE"
grep -q 'OpenClaw deployment finished' "$OUTPUT_ONE"

echo "DRY_RUN idempotency test passed"
