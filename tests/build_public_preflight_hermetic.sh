#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

set +e
(
  cd "$REPO_DIR"
  DRY_RUN=1 OPENCLAW_ACCESS_MODE=public OVH_ENDPOINT_API_KEY=test-key sh ./build.sh > "$TMP_DIR/missing.out" 2>&1
)
status=$?
set -e

[ "$status" -ne 0 ]
grep -q 'Environment variable TRAEFIK_ACME_EMAIL is required' "$TMP_DIR/missing.out"

(
  cd "$REPO_DIR"
  DRY_RUN=1 OPENCLAW_ACCESS_MODE=public OVH_ENDPOINT_API_KEY=test-key TRAEFIK_ACME_EMAIL=admin@example.com OPENCLAW_DOMAIN=openclaw.example.com sh ./build.sh > "$TMP_DIR/ok.out"
)

grep -q 'render .*openclaw-compose.public.yml.tmpl' "$TMP_DIR/ok.out"
grep -q '\[DRY_RUN\] validate https://openclaw.example.com with curl' "$TMP_DIR/ok.out"

echo 'build_public_preflight_hermetic: ok'
