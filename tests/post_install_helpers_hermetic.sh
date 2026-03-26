#!/usr/bin/env sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$REPO_DIR/update.sh" "$TMP_DIR/update.sh"
cp "$REPO_DIR/add_tool.sh" "$TMP_DIR/add_tool.sh"
chmod +x "$TMP_DIR/update.sh" "$TMP_DIR/add_tool.sh"

cat > "$TMP_DIR/build.sh" << 'EOS'
#!/usr/bin/env sh
set -eu
printf 'build called\n'
printf 'signal=%s github=%s himalaya=%s coding_agent=%s\n' \
  "${OPENCLAW_ENABLE_SIGNAL:-0}" \
  "${OPENCLAW_ENABLE_GITHUB_SKILL:-0}" \
  "${OPENCLAW_ENABLE_HIMALAYA_SKILL:-0}" \
  "${OPENCLAW_ENABLE_CODING_AGENT_SKILL:-0}"
printf 'openclaw_image=%s skip_build=%s\n' \
  "${OPENCLAW_IMAGE:-unset}" \
  "${SKIP_OPENCLAW_IMAGE_BUILD:-unset}"
EOS
chmod +x "$TMP_DIR/build.sh"

mkdir -p "$TMP_DIR/openclaw"
cat > "$TMP_DIR/openclaw/.env" << 'EOS'
OVH_ENDPOINT_API_KEY=from-env-file
EOS

cat > "$TMP_DIR/.sync-build.env" << 'EOS'
OPENCLAW_IMAGE=ghcr.io/example/openclaw-agent:20260326
SKIP_OPENCLAW_IMAGE_BUILD=1
EOS

UPDATE_OUT="$TMP_DIR/update.out"
(
  cd "$TMP_DIR"
  OPENCLAW_DIR="$TMP_DIR/openclaw" GIT_PULL=auto RUN_BUILD=1 sh ./update.sh > "$UPDATE_OUT"
)

grep -q 'Skipping repository update (no .git checkout found; GIT_PULL=auto)' "$UPDATE_OUT"
grep -q 'Loaded OVH_ENDPOINT_API_KEY from .*openclaw/.env' "$UPDATE_OUT"
grep -q 'Loaded deployment defaults from .*/.sync-build.env' "$UPDATE_OUT"
grep -q 'build called' "$UPDATE_OUT"
grep -q 'openclaw_image=ghcr.io/example/openclaw-agent:20260326 skip_build=1' "$UPDATE_OUT"

ADD_TOOL_OUT="$TMP_DIR/add_tool.out"
(
  cd "$TMP_DIR"
  OPENCLAW_DIR="$TMP_DIR/openclaw" TOOL=github sh ./add_tool.sh > "$ADD_TOOL_OUT"
)

grep -q 'Loaded OVH_ENDPOINT_API_KEY from .*openclaw/.env' "$ADD_TOOL_OUT"
grep -q 'Enabling optional tool: github' "$ADD_TOOL_OUT"
grep -q 'signal=0 github=1 himalaya=0 coding_agent=0' "$ADD_TOOL_OUT"

ADD_TOOL_DRY_OUT="$TMP_DIR/add_tool_dry.out"
(
  cd "$TMP_DIR"
  OPENCLAW_DIR="$TMP_DIR/openclaw" DRY_RUN=1 TOOL=signal sh ./add_tool.sh > "$ADD_TOOL_DRY_OUT"
)

grep -q '\[DRY_RUN\] sh .*build.sh' "$ADD_TOOL_DRY_OUT"
if grep -q 'build called' "$ADD_TOOL_DRY_OUT"; then
  echo "add_tool.sh DRY_RUN unexpectedly executed build.sh" >&2
  exit 1
fi

echo "post-install helper hermetic test passed"
