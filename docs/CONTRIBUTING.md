# Contributing

## Principles

- Keep shell scripts POSIX-compatible unless explicitly migrating tooling.
- Prefer small, auditable changes with paired documentation updates.
- Preserve backward compatibility for existing environment variables when possible.

## Local checks

Run before opening a PR:

```bash
make check
```

This runs:

- `sh -n build.sh build-interactive.sh`
- `shellcheck build.sh build-interactive.sh sync.sh`
- `shfmt -d build.sh build-interactive.sh sync.sh`

If `shellcheck` or `shfmt` are unavailable, install them before submitting changes.

## Change requirements

- Update `README.md` for user-facing behavior changes.
- Update docs under `docs/` for operational behavior changes.
- Update `CHANGELOG.md` under `Unreleased` for every merged change.
- Update `docs/FOLLOW_UP_PLAN.md` when scope or priorities shift.
- Include a brief test/verification summary in PR description.
