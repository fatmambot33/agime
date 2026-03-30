#!/bin/bash
# -------------------------------------------------------------
# Step 4 – OpenClaw Installation
# Author: Pablo FOURCAT
# Purpose: Clone OpenClaw repo, prepare workspace, and run Docker setup
# Note: This script assumes Docker is installed and usable without sudo
# -------------------------------------------------------------

set -e
set -u

# Set OpenClaw installation directory
OPENCLAW_DIR="$HOME/openclaw"
WORKSPACE_DIR="$HOME/.openclaw/workspace"

echo "=== Cloning OpenClaw repository ==="
if [ ! -d "$OPENCLAW_DIR" ]; then
    git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_DIR"
else
    echo "OpenClaw directory already exists, skipping clone."
fi

cd "$OPENCLAW_DIR"

echo "=== Preparing workspace directories ==="
mkdir -p "$WORKSPACE_DIR"

echo "=== Ensuring proper ownership of OpenClaw files ==="
# Replace 'ubuntu' with your actual username if different
sudo chown -R "$USER":"$USER" "$OPENCLAW_DIR"

echo "=== Launching OpenClaw Docker setup wizard ==="
# This runs the official docker-setup.sh script
./docker-setup.sh

echo
echo "✅ OpenClaw installation complete!"
echo "Your workspace is ready at: $WORKSPACE_DIR"
echo "OPENCLAW_GATEWAY_TOKEN: $(grep '^OPENCLAW_GATEWAY_TOKEN=' /home/ubuntu/openclaw/.env | cut -d '=' -f2)"