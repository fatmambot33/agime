SHELL := /bin/sh

SCRIPTS := build.sh configure.sh sync.sh backup.sh update.sh image.sh add_tool.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh scripts/build_custom_image.sh scripts/optional_tools/common.sh scripts/optional_tools/github.sh scripts/optional_tools/himalaya.sh scripts/optional_tools/coding_agent.sh scripts/run_security_audit.sh scripts/install_security_audit_cron.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/configure_backup_hermetic.sh tests/configure_autoload_env_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh

.PHONY: check check-strict ensure-tools syntax lint fmt-check smoke idempotency security sync-test backup-restore-test interactive-backup-test interactive-env-autoload-test ownership-config-test post-install-helpers-test security-audit-scripts security-audit install-security-cron

check: syntax smoke idempotency security sync-test backup-restore-test interactive-backup-test interactive-env-autoload-test ownership-config-test post-install-helpers-test security-audit-scripts

check-strict: syntax lint fmt-check smoke idempotency security sync-test backup-restore-test interactive-backup-test interactive-env-autoload-test ownership-config-test post-install-helpers-test security-audit-scripts

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

security:
	sh tests/security_template_checks.sh

sync-test:
	sh tests/sync_hermetic.sh

backup-restore-test:
	sh tests/backup_restore_hermetic.sh

interactive-backup-test:
	sh tests/configure_backup_hermetic.sh

interactive-env-autoload-test:
	sh tests/configure_autoload_env_hermetic.sh

ownership-config-test:
	sh tests/ownership_config_dir_hermetic.sh

security-audit-scripts:
	sh tests/security_audit_scripts_hermetic.sh

security-audit:
	sh scripts/run_security_audit.sh

install-security-cron:
	sh scripts/install_security_audit_cron.sh

post-install-helpers-test:
	sh tests/post_install_helpers_hermetic.sh
