#!/usr/bin/env sh
# shellcheck shell=sh

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/scripts/lib/common.sh"

update_maybe_pull() {
  case "$GIT_PULL" in
    auto)
      if [ -d "$SCRIPT_DIR/.git" ]; then
        if ! git -C "$SCRIPT_DIR" pull --ff-only; then
          if [ "${ALLOW_STALE_CODE:-0}" = "1" ]; then
            warn "git pull failed in auto mode; continuing due to ALLOW_STALE_CODE=1"
          else
            fail "git pull failed in auto mode. Set ALLOW_STALE_CODE=1 to continue with local checkout."
          fi
        fi
      fi
      ;;
    1)
      [ -d "$SCRIPT_DIR/.git" ] || fail "cannot use GIT_PULL=1 outside a git checkout"
      git -C "$SCRIPT_DIR" pull --ff-only
      ;;
    0) ;;
    *) fail "GIT_PULL must be auto, 1, or 0" ;;
  esac
}

update_maybe_backup() {
  case "$RUN_BACKUP" in
    1)
      env BACKUP_OUTPUT="$BACKUP_OUTPUT" sh "$BACKUP_SCRIPT"
      ;;
    0) ;;
    *) fail "RUN_BACKUP must be 1 or 0" ;;
  esac
}

update_maybe_build() {
  case "$RUN_BUILD" in
    1) sh "$BUILD_SCRIPT" ;;
    0) ;;
    *) fail "RUN_BUILD must be 1 or 0" ;;
  esac
}
