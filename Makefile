SHELL := /bin/sh

SCRIPTS := build.sh build-interactive.sh sync.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh

.PHONY: check check-strict syntax lint fmt-check smoke

check: syntax smoke

check-strict: syntax lint fmt-check smoke

syntax:
	sh -n $(SCRIPTS)

lint:
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo "shellcheck is required for 'make lint'"; \
		exit 1; \
	}
	shellcheck -S error -e SC1091,SC2034,SC2154 $(SCRIPTS)

fmt-check:
	@command -v shfmt >/dev/null 2>&1 || { \
		echo "shfmt is required for 'make fmt-check'"; \
		exit 1; \
	}
	shfmt -i 2 -ci -sr -d $(SCRIPTS)

smoke:
	sh tests/smoke_dry_run.sh
