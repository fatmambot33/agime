# Contributing

## Architecture map

- Top-level entrypoints (`build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`):
  orchestration entrypoints only.
- `scripts/build_lib.sh` + `scripts/build_steps.sh`:
  deploy engine internals and build-time behavior.
- `scripts/lib/*.sh`:
  shared orchestration helpers used by top-level entrypoints.
- `templates/*`:
  rendered assets only (no runtime orchestration logic).
- `tests/*`:
  deterministic smoke/idempotency/hermetic/failure/security checks.

## Decision checklist (before adding/changing files)

1. Is this change in the minimal six-entrypoint contract?
2. Can logic be placed in an existing `scripts/lib/*` helper instead of top-level script growth?
3. Does a behavior change require test updates under `tests/`?
4. Do docs under `README.md` and `docs/` match new behavior in the same PR?

## Required checks

```sh
sh -n build.sh setup.sh sync.sh
make check
```

Prefer strict checks before opening a PR:

```sh
make check-strict
```
