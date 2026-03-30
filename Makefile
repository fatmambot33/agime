SHELL := /bin/sh

SCRIPTS := build.sh sync.sh backup.sh update.sh image.sh restore.sh setup.sh scripts/build_lib.sh scripts/build_steps.sh scripts/build_custom_image.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/sync_hermetic.sh tests/backup_restore_hermetic.sh tests/build_custom_image_daemon_check_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh

.PHONY: check check-strict ensure-tools syntax lint fmt-check smoke idempotency sync-test backup-restore-test custom-image-daemon-check-test ownership-config-test post-install-helpers-test

check: syntax smoke idempotency sync-test backup-restore-test ownership-config-test post-install-helpers-test

check-strict: syntax lint fmt-check smoke idempotency sync-test backup-restore-test ownership-config-test post-install-helpers-test

ensure-tools:
	@if ! command -v shellcheck >/dev/null 2>&1 || ! command -v shfmt >/dev/null 2>&1; then \
		if command -v apt-get >/dev/null 2>&1; then \
			echo "Installing missing shell tools (shellcheck, shfmt)"; \
			sudo apt-get update && sudo apt-get install -y shellcheck shfmt; \
		else \
			echo "shellcheck/shfmt are required and apt-get is unavailable"; \
			exit 1; \
		fi; \
	fi

syntax:
	sh -n $(SCRIPTS)

lint: ensure-tools
	shellcheck -S error -e SC1091,SC2034,SC2154 $(SCRIPTS)

fmt-check: ensure-tools
	shfmt -i 2 -ci -sr -d $(SCRIPTS)

smoke:
	sh tests/smoke_dry_run.sh

idempotency:
	sh tests/idempotency_dry_run.sh

sync-test:
	sh tests/sync_hermetic.sh

backup-restore-test:
	sh tests/backup_restore_hermetic.sh

custom-image-daemon-check-test:
	sh tests/build_custom_image_daemon_check_hermetic.sh

ownership-config-test:
	sh tests/ownership_config_dir_hermetic.sh

post-install-helpers-test:
	sh tests/post_install_helpers_hermetic.sh
