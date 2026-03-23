SHELL := /bin/sh

SCRIPTS := build.sh build-interactive.sh sync.sh tests/smoke_dry_run.sh

.PHONY: check syntax lint fmt-check smoke

check: syntax lint fmt-check smoke

syntax:
	sh -n $(SCRIPTS)

lint:
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo "shellcheck is required for 'make lint'"; \
		exit 1; \
	}
	shellcheck $(SCRIPTS)

fmt-check:
	@command -v shfmt >/dev/null 2>&1 || { \
		echo "shfmt is required for 'make fmt-check'"; \
		exit 1; \
	}
	shfmt -d $(SCRIPTS)

smoke:
	sh tests/smoke_dry_run.sh
