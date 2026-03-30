#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

required_templates='templates/openclaw-compose.ssh-tunnel.yml.tmpl templates/openclaw-compose.public.yml.tmpl templates/traefik-compose.yml.tmpl templates/openclaw.json.tmpl'
for file in $required_templates; do
  [ -f "$REPO_DIR/$file" ] || {
    echo "missing template: $file" >&2
    exit 1
  }
done

# Guard against accidental hardcoded secrets.
if rg -n 'OVH_ENDPOINT_API_KEY=.*[A-Za-z0-9]{10,}' "$REPO_DIR/templates" > /dev/null 2>&1; then
  echo 'detected suspicious hardcoded OVH key pattern in templates' >&2
  exit 1
fi

echo 'security_template_checks: ok'
