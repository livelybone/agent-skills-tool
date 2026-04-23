# Changelog

## Unreleased
- batch install: passing a directory without a root `SKILL.md` installs every immediate subdirectory that has one
- add `-r/--remove` to uninstall a skill by name
- align Tinify API key resolution with figma-export token handling
- document `figma-export` preference to implement shadows in code instead of exporting them
- **multi-agent-loop v3.0 (breaking)**: remove `peer` role entirely; restructure workdir so `agent-task.md` is generated once per task at `<task-name>/agent-task.md` and each round's artifacts live in `<task-name>/r<N>/` — guarantees cross-round task consistency by file-system layout. `run_agent.sh` signature becomes `<runner> <task-name> <round-number> [workdir]` (prompt-file and role args dropped); round-cap gate now checks the explicit `<round-number>` with a `--allow-round-overflow` escape; judgment gate scans `<task-name>/r*/` within the same task. `validate_task.sh` drops its role arg. Task-name convention drops the `-r<N>` suffix.
