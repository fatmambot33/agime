# AGENTS.md

## Scope
This file governs the entire repository.

## Mission
Maintain and evolve this repo as a reliable, auditable deployment toolkit for OpenClaw + Traefik on VPS hosts.

## Working rules for agents

1. **Safety first**
   - Never remove existing setup paths without a replacement migration path.
   - Keep defaults conservative and explicit.

2. **Script compatibility**
   - Primary shell target is POSIX `sh` unless a migration is explicitly approved.
   - Preserve existing environment-variable interfaces when possible.

3. **Documentation parity**
   - Any behavior change in scripts must be reflected in `README.md` and relevant files under `docs/` in the same change.

4. **Validation expectations**
   - At minimum, run `sh -n build.sh setup.sh sync.sh` after editing top-level shell entrypoints.
   - Prefer `make check` for full syntax + hermetic validation before opening a PR.
   - Prefer adding small, deterministic validation checks over manual-only verification.

5. **Roadmap discipline**
   - Align new work with `docs/FOLLOW_UP_PLAN.md`.
   - If priorities change, update the plan in the same PR and state why.

## Preferred structure

- Root: executable scripts and short entrypoint docs.
- `docs/`: deep-dive docs (reviews, plans, runbooks).
- `tests/`: script-level automated checks (dry-run smoke and idempotency coverage today; expand over time).
