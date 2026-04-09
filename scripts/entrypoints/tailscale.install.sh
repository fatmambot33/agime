#!/usr/bin/env sh
# shellcheck shell=sh

set -eu

if command -v tailscale > /dev/null 2>&1; then
  echo "Tailscale is already installed: $(tailscale version | head -n 1)"
  exit 0
fi

if ! command -v curl > /dev/null 2>&1; then
  echo "Error: curl is required to install Tailscale." >&2
  exit 1
fi

if ! command -v sh > /dev/null 2>&1; then
  echo "Error: sh is required to install Tailscale." >&2
  exit 1
fi

echo "Installing Tailscale using the official installer..."
curl -fsSL https://tailscale.com/install.sh | sh

if command -v tailscale > /dev/null 2>&1; then
  echo "Tailscale installation complete: $(tailscale version | head -n 1)"
  exit 0
fi

echo "Error: tailscale command was not found after installation." >&2
exit 1
