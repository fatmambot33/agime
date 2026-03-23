SHELL := /bin/sh

SCRIPTS := build.sh build-interactive.sh sync.sh scripts/build_lib.sh scripts/build_steps.sh scripts/run_security_audit.sh scripts/install_security_audit_cron.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh

.PHONY: check check-strict ensure-tools syntax lint fmt-check smoke idempotency security security-audit install-security-cron

check: syntax smoke idempotency security

check-strict: syntax lint fmt-check smoke idempotency security

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

security-audit:
	sh scripts/run_security_audit.sh

install-security-cron:
	sh scripts/install_security_audit_cron.sh
