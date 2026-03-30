# Release Process

Date: 2026-03-30

## Versioning policy

- Use semantic versioning tags: `vMAJOR.MINOR.PATCH`.
- `PATCH`: bug fixes, no intended behavior drift.
- `MINOR`: backwards-compatible feature or workflow additions.
- `MAJOR`: intentional breaking behavior changes.

## Release checklist

1. Run local validation:
   - `make check-strict`
2. Confirm docs parity:
   - `README.md`
   - `docs/OPERATIONS.md`
   - `docs/DEPLOY_OPENCLAW_DOCKER_VPS.md`
   - `docs/DEPRECATIONS.md` (if relevant)
3. Update `CHANGELOG.md` with release notes.
4. Create annotated git tag:
   - `git tag -a vX.Y.Z -m "release vX.Y.Z"`
5. Push branch + tags:
   - `git push origin <branch>`
   - `git push origin vX.Y.Z`
6. Publish release notes from changelog summary.

## Rollback policy

- If a release is broken, publish a patch release with fix-forward changes.
- Keep deprecation shims for at least one release cycle unless security requires immediate removal.
