SHELL := /bin/sh

SCRIPTS := build.sh sync.sh setup.sh backup.sh restore.sh update.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/sync_hermetic.sh tests/backup_restore_hermetic.sh

.PHONY: check check-strict ensure-tools syntax lint fmt-check smoke idempotency sync-test backup-restore-test

check: syntax smoke idempotency sync-test backup-restore-test

check-strict: syntax lint fmt-check smoke idempotency sync-test backup-restore-test

ensure-tools:
	@if ! command -v shellcheck >/dev/null 2>&1 || ! command -v shfmt >/dev/null 2>&1; then \
		echo "shellcheck and shfmt are required"; \
		exit 1; \
	fi

syntax:
	sh -n $(SCRIPTS)
	sh -n build.sh setup.sh sync.sh

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
