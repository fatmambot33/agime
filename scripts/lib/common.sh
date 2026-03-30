#!/usr/bin/env sh
# shellcheck shell=sh

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_nonempty() {
  key=$1
  value=$2
  [ -n "$value" ] || fail "$key is required"
}

canonicalize_home_path() {
  value=$1
  home_dir=${HOME:-}
  [ -n "$home_dir" ] || {
    printf '%s' "$value"
    return 0
  }

  case "$value" in
    "$home_dir")
      printf '~'
      ;;
    "$home_dir"/*)
      printf '~/%s' "${value#"$home_dir"/}"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

remote_home_path() {
  value=$1
  case "$value" in
    '~')
      printf '$HOME'
      ;;
    '~/'*)
      printf '$HOME/%s' "${value#\~/}"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}
