# Contributing

## Architecture constraints

- Keep top-level entrypoints limited to:
  `build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`.
- Keep shared orchestration logic in `scripts/lib/`.
- Keep deploy-step implementation in `scripts/build_lib.sh` and `scripts/build_steps.sh`.
- Keep rendered assets in `templates/` only.
- Use POSIX `sh`.

## Required checks

```sh
sh -n build.sh setup.sh sync.sh
make check
```

Prefer strict checks before opening a PR:

```sh
make check-strict
```

## Test expectations

- Add deterministic hermetic coverage for behavior changes.
- Include failure-path checks for new safety rails.
- Keep template security checks in `tests/security_template_checks.sh` updated when templates change.
