#!/usr/bin/env sh
# shellcheck shell=sh

set -eu

TRAEFIK_ACME_EMAIL=${TRAEFIK_ACME_EMAIL:-}
TRAEFIK_DIR=${TRAEFIK_DIR:-"$HOME/docker/traefik"}
TRAEFIK_VERSION=${TRAEFIK_VERSION:-"v2.11"}

require_cmd() {
  if ! command -v "$1" > /dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

require_nonempty() {
  key=$1
  value=$2
  if [ -z "$value" ]; then
    echo "Error: $key is required." >&2
    exit 1
  fi
}

require_cmd docker
require_nonempty "TRAEFIK_ACME_EMAIL" "$TRAEFIK_ACME_EMAIL"

mkdir -p "$TRAEFIK_DIR/letsencrypt"
chmod 700 "$TRAEFIK_DIR/letsencrypt"
touch "$TRAEFIK_DIR/letsencrypt/acme.json"
chmod 600 "$TRAEFIK_DIR/letsencrypt/acme.json"

cat > "$TRAEFIK_DIR/docker-compose.yml" << EOF2
services:
  traefik:
    image: traefik:$TRAEFIK_VERSION
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=$TRAEFIK_ACME_EMAIL"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - proxy

networks:
  proxy:
    external: true
EOF2

if ! docker network inspect proxy > /dev/null 2>&1; then
  docker network create proxy > /dev/null
fi

(
  cd "$TRAEFIK_DIR"
  docker compose up -d
)

echo "Traefik installation complete in $TRAEFIK_DIR"
