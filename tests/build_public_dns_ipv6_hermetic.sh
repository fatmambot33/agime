#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SCRIPT_DIR="$REPO_DIR"
# shellcheck source=scripts/build_lib.sh
. "$REPO_DIR/scripts/build_lib.sh"
# shellcheck source=scripts/build_steps.sh
. "$REPO_DIR/scripts/build_steps.sh"

OPENCLAW_DOMAIN='openclaw.example.com'
POST_BUILD_TEST_ATTEMPTS=1
POST_BUILD_TEST_DELAY_SECONDS=0
POST_BUILD_TEST_CONNECT_TIMEOUT_SECONDS=1
POST_BUILD_TEST_MAX_TIME_SECONDS=2
PUBLIC_HEALTH_PATH='/healthz'
PUBLIC_EXPECT_SERVER_HEADER='traefik'
PUBLIC_HEALTH_EXPECT_SUBSTRING='ok'

getent() {
  case "$1" in
    ahosts)
      printf '2001:db8::10 STREAM %s\n' "$2"
      ;;
    hosts)
      return 1
      ;;
  esac
}

curl() {
  header_file=''
  output_file=''
  url=''

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dump-header)
        header_file=$2
        shift 2
        ;;
      --output)
        output_file=$2
        shift 2
        ;;
      http://*|https://*)
        url=$1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  case "$url" in
    "https://$OPENCLAW_DOMAIN/")
      [ -n "$header_file" ] && printf 'server: traefik\n' > "$header_file"
      printf '200'
      ;;
    "https://$OPENCLAW_DOMAIN$PUBLIC_HEALTH_PATH")
      [ -n "$output_file" ] && printf 'ok\n' > "$output_file"
      printf '200'
      ;;
    *)
      return 1
      ;;
  esac
}

validate_public_mode

echo 'build_public_dns_ipv6_hermetic: ok'
