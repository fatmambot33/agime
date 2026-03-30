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
- `sync-test`
- `backup-restore-test`
- `ownership-config-test`
- `post-install-helpers-test`

`make check-strict` runs:

- `sh -n build.sh sync.sh backup.sh update.sh image.sh restore.sh setup.sh scripts/build_lib.sh scripts/build_steps.sh scripts/build_custom_image.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/sync_hermetic.sh tests/backup_restore_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh`
- `shellcheck -S error -e SC1091,SC2034,SC2154 build.sh sync.sh backup.sh update.sh image.sh restore.sh setup.sh scripts/build_lib.sh scripts/build_steps.sh scripts/build_custom_image.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/sync_hermetic.sh tests/backup_restore_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh`
- `shfmt -i 2 -ci -sr -d build.sh sync.sh backup.sh update.sh image.sh restore.sh setup.sh scripts/build_lib.sh scripts/build_steps.sh scripts/build_custom_image.sh tests/smoke_dry_run.sh tests/idempotency_dry_run.sh tests/sync_hermetic.sh tests/backup_restore_hermetic.sh tests/ownership_config_dir_hermetic.sh tests/post_install_helpers_hermetic.sh`
- `sh tests/smoke_dry_run.sh`
- `sh tests/idempotency_dry_run.sh`
- `sh tests/sync_hermetic.sh`
- `sh tests/backup_restore_hermetic.sh`
- `sh tests/ownership_config_dir_hermetic.sh`
- `sh tests/post_install_helpers_hermetic.sh`

If `shellcheck` or `shfmt` are unavailable, `make check-strict` will try to install them via `apt-get`.

## Change requirements

- Update `README.md` for user-facing behavior changes.
- Update docs under `docs/` for operational behavior changes.
- Update `CHANGELOG.md` under `Unreleased` for every merged change.
- Update `docs/FOLLOW_UP_PLAN.md` when scope or priorities shift.
- Include a brief test/verification summary in PR description.
- Keep script execute bits correct (`chmod +x`) when adding/updating runnable `.sh` entrypoints.
