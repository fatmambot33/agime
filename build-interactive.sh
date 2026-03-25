#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
printf '%s\n' 'Warning: build-interactive.sh is deprecated; use configure.sh instead.' >&2
exec sh "$SCRIPT_DIR/configure.sh" "$@"
