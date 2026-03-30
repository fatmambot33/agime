#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

(
  cd "$REPO_DIR"
  DRY_RUN=1 OVH_ENDPOINT_API_KEY=test-key sh ./build.sh > "$OUT"
)

grep -q 'DRY_RUN=1 enabled; no system or Docker changes will be applied' "$OUT"
grep -q 'Access mode is ssh-tunnel; skipping Traefik and proxy network setup' "$OUT"
grep -q 'OpenClaw deployment finished' "$OUT"

echo 'smoke_dry_run: ok'
