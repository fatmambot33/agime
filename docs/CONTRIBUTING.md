# Contributing

## Principles

- Keep shell scripts POSIX-compatible unless explicitly migrating tooling.
- Prefer small, auditable changes with paired documentation updates.
- Preserve backward compatibility for existing environment variables when possible.

## Local checks

Run before opening a PR (Linux/OVH VPS behavior is the primary validation target):

```bash
make check-strict
```

`make check` runs:

- `syntax`
- `smoke`
- `idempotency`
- `security`
- `sync-test`
- `backup-restore-test`
- `interactive-backup-test`
- `ownership-config-test`
- `post-install-helpers-test`
- `security-audit-scripts`

`make check-strict` runs:

- `sh -n build.sh build-interactive.sh sync.sh backup.sh update.sh add_tool.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh scripts/optional_tools/common.sh scripts/optional_tools/github.sh scripts/optional_tools/himalaya.sh scripts/optional_tools/coding_agent.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/build_interactive_backup_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh`
- `shellcheck -S error -e SC1091,SC2034,SC2154 build.sh build-interactive.sh sync.sh backup.sh update.sh add_tool.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh scripts/optional_tools/common.sh scripts/optional_tools/github.sh scripts/optional_tools/himalaya.sh scripts/optional_tools/coding_agent.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/build_interactive_backup_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh`
- `shfmt -i 2 -ci -sr -d build.sh build-interactive.sh sync.sh backup.sh update.sh add_tool.sh restore.sh scripts/build_lib.sh scripts/build_steps.sh scripts/optional_tools/common.sh scripts/optional_tools/github.sh scripts/optional_tools/himalaya.sh scripts/optional_tools/coding_agent.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/security_template_checks.sh tests/sync_hermetic.sh tests/security_audit_scripts_hermetic.sh tests/backup_restore_hermetic.sh tests/build_interactive_backup_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh`
- `sh tests/smoke_dry_run.sh`
- `sh tests/idempotency_dry_run.sh`
- `sh tests/security_template_checks.sh`
- `sh tests/sync_hermetic.sh`
- `sh tests/backup_restore_hermetic.sh`
- `sh tests/build_interactive_backup_hermetic.sh`
- `sh tests/ownership_config_dir_hermetic.sh`
- `sh tests/post_install_helpers_hermetic.sh`
- `sh tests/security_audit_scripts_hermetic.sh`

If `shellcheck` or `shfmt` are unavailable, `make check-strict` will try to install them via `apt-get`.

## Change requirements

- Update `README.md` for user-facing behavior changes.
- Update docs under `docs/` for operational behavior changes.
- Update `CHANGELOG.md` under `Unreleased` for every merged change.
- Update `docs/FOLLOW_UP_PLAN.md` when scope or priorities shift.
- Include a brief test/verification summary in PR description.
- Keep script execute bits correct (`chmod +x`) when adding/updating runnable `.sh` entrypoints.
