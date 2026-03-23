# Contributing

## Principles

- Keep shell scripts POSIX-compatible unless explicitly migrating tooling.
- Prefer small, auditable changes with paired documentation updates.
- Preserve backward compatibility for existing environment variables when possible.

## Local checks

Run before opening a PR:

```bash
make check-strict
```

`make check` is a lightweight local check (`syntax` + `smoke`).

`make check-strict` runs:

- `sh -n build.sh build-interactive.sh sync.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh`
- `shellcheck -S error -e SC1091,SC2034,SC2154 build.sh build-interactive.sh sync.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh`
- `shfmt -i 2 -ci -sr -d build.sh build-interactive.sh sync.sh scripts/build_lib.sh scripts/build_steps.sh tests/smoke_dry_run.sh`
- `sh tests/smoke_dry_run.sh`

If `shellcheck` or `shfmt` are unavailable, `make check-strict` will try to install them via `apt-get`.

## Change requirements

- Update `README.md` for user-facing behavior changes.
- Update docs under `docs/` for operational behavior changes.
- Update `CHANGELOG.md` under `Unreleased` for every merged change.
- Update `docs/FOLLOW_UP_PLAN.md` when scope or priorities shift.
- Include a brief test/verification summary in PR description.
- Keep script execute bits correct (`chmod +x`) when adding/updating runnable `.sh` entrypoints.
