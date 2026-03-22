# Contributing

## Principles

- Keep shell scripts POSIX-compatible unless explicitly migrating tooling.
- Prefer small, auditable changes with paired documentation updates.
- Preserve backward compatibility for existing environment variables when possible.

## Local checks

Run before opening a PR:

```bash
sh -n build.sh build-interactive.sh
```

If available in your environment, also run:

```bash
shellcheck build.sh build-interactive.sh
```

## Change requirements

- Update `README.md` for user-facing behavior changes.
- Update `docs/FOLLOW_UP_PLAN.md` when scope or priorities shift.
- Include a brief test/verification summary in PR description.
