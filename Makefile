SHELL := /bin/sh

SCRIPTS := build.sh sync.sh setup.sh backup.sh restore.sh update.sh scripts/build_lib.sh scripts/build_steps.sh scripts/lib/common.sh scripts/lib/sync.sh scripts/lib/setup.sh scripts/lib/update.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/sync_hermetic.sh tests/backup_restore_hermetic.sh tests/failure_paths_hermetic.sh tests/security_template_checks.sh tests/build_public_preflight_hermetic.sh tests/docker_install_flow_hermetic.sh tests/sync_env_edge_cases_hermetic.sh tests/template_render_hermetic.sh tests/release_policy_docs_hermetic.sh tests/restore_hardening_hermetic.sh tests/openclaw_env_image_normalization_hermetic.sh tests/build_public_dns_ipv6_hermetic.sh

.PHONY: check check-strict ensure-tools syntax lint fmt-check smoke idempotency sync-test backup-restore-test failure-paths security public-preflight docker-install-flow sync-env-edges template-render release-policy-docs restore-hardening env-image-normalization public-dns-ipv6

check: syntax smoke idempotency sync-test backup-restore-test failure-paths security public-preflight docker-install-flow sync-env-edges template-render release-policy-docs restore-hardening env-image-normalization public-dns-ipv6

check-strict: syntax lint fmt-check smoke idempotency sync-test backup-restore-test failure-paths security public-preflight docker-install-flow sync-env-edges template-render release-policy-docs restore-hardening env-image-normalization public-dns-ipv6

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

failure-paths:
	sh tests/failure_paths_hermetic.sh

security:
	sh tests/security_template_checks.sh

public-preflight:
	sh tests/build_public_preflight_hermetic.sh

docker-install-flow:
	sh tests/docker_install_flow_hermetic.sh

sync-env-edges:
	sh tests/sync_env_edge_cases_hermetic.sh

template-render:
	sh tests/template_render_hermetic.sh

release-policy-docs:
	sh tests/release_policy_docs_hermetic.sh

restore-hardening:
	sh tests/restore_hardening_hermetic.sh

env-image-normalization:
	sh tests/openclaw_env_image_normalization_hermetic.sh

public-dns-ipv6:
	sh tests/build_public_dns_ipv6_hermetic.sh
