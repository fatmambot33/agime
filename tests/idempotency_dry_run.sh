#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ONE=$(mktemp)
TWO=$(mktemp)
trap 'rm -f "$ONE" "$TWO"' EXIT

(
  cd "$REPO_DIR"
  DRY_RUN=1 OVH_ENDPOINT_API_KEY=test-key sh ./build.sh > "$ONE"
  DRY_RUN=1 OVH_ENDPOINT_API_KEY=test-key sh ./build.sh > "$TWO"
)

cmp -s "$ONE" "$TWO"

echo 'idempotency_dry_run: ok'
