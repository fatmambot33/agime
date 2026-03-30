# Contributing

## Architecture constraints

- Keep top-level entrypoints limited to:
  `build.sh`, `sync.sh`, `setup.sh`, `backup.sh`, `restore.sh`, `update.sh`.
- Keep shared implementation details in `scripts/`.
- Keep rendered assets in `templates/` only.
- Prefer POSIX `sh` and deterministic behavior.

## Required local validation

Run before opening a PR:

```sh
sh -n build.sh setup.sh sync.sh
make check
```

Prefer strict checks when available:

```sh
make check-strict
```

## Testing policy

- Add or update hermetic tests in `tests/` for behavior changes.
- Prefer dry-run, mock-driven, and idempotency-oriented checks over manual-only validation.
