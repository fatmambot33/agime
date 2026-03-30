#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

[ -f "$REPO_DIR/docs/RELEASE_PROCESS.md" ]
[ -f "$REPO_DIR/docs/COMPATIBILITY_POLICY.md" ]

grep -q '^## Versioning policy' "$REPO_DIR/docs/RELEASE_PROCESS.md"
grep -q '^## Release checklist' "$REPO_DIR/docs/RELEASE_PROCESS.md"
grep -q '^## Rollback policy' "$REPO_DIR/docs/RELEASE_PROCESS.md"

grep -q '^## Runtime compatibility scope' "$REPO_DIR/docs/COMPATIBILITY_POLICY.md"
grep -q '^## Compatibility matrix policy' "$REPO_DIR/docs/COMPATIBILITY_POLICY.md"
grep -q '^## Testing policy per release' "$REPO_DIR/docs/COMPATIBILITY_POLICY.md"

echo 'release_policy_docs_hermetic: ok'
