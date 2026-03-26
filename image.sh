#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
IMAGE_HELPER="$SCRIPT_DIR/scripts/build_custom_image.sh"

[ -f "$IMAGE_HELPER" ] || {
  printf 'Error: image helper not found at %s\n' "$IMAGE_HELPER" >&2
  exit 1
}

sh "$IMAGE_HELPER" "$@"
