#!/bin/bash

set -e

echo "=== OpenClaw VPS Setup ==="
echo ""

# --- INPUTS ---
read -p "Domain (e.g. ai.example.com): " DOMAIN
read -p "Email (Let's Encrypt): " EMAIL
read -p "OpenClaw token: " TOKEN

if [[ -z "$DOMAIN" || -z "$EMAIL" || -z "$TOKEN" ]]; then
  echo "❌ All fields are required."
  exit 1
fi

# --- INSTALL DOCKER IF NEEDED ---
if ! command -v docker &> /dev/null; then
  echo "📦 Installing Docker..."
  sudo apt update
  sudo apt install -y docker.io docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
fi

# --- CREATE APP DIR ---
APP_DIR="$HOME/openclaw"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# --- GENERATE DOCKER COMPOSE ---
cat > docker-compose.yml <<EOF
version: "3.8"

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--certificatesresolvers.le.acme.tlschallenge=true"
      - "--certificatesresolvers.le.acme.email=${EMAIL}"
      - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "traefik_data:/letsencrypt"
    networks:
      - web

  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: "${TOKEN}"
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "lan",
        "--port",
        "18789"
      ]
    volumes:
      - openclaw_data:/home/node/.openclaw
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=web"
      - "traefik.http.routers.openclaw.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.openclaw.entrypoints=websecure"
      - "traefik.http.routers.openclaw.tls.certresolver=le"
      - "traefik.http.services.openclaw.loadbalancer.server.port=18789"
    networks:
      - web

volumes:
  traefik_data:
  openclaw_data:

networks:
  web:
EOF

echo "✅ docker-compose.yml created"

# --- FIREWALL (optional but recommended) ---
if command -v ufw &> /dev/null; then
  echo "🔥 Configuring firewall..."
  sudo ufw allow 22
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw --force enable
fi

# --- START STACK ---
echo "🚀 Starting OpenClaw..."
docker compose up -d

echo ""
echo "✅ Done!"
echo "🌐 Access your app at: https://${DOMAIN}"
echo ""
echo "⚠️ Make sure your DNS points to this VPS!"