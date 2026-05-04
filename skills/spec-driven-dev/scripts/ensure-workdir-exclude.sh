#!/usr/bin/env bash
# ensure-workdir-exclude.sh
# Idempotently add `.spec-driven-dev/` to `<workdir>/.git/info/exclude`
# so that orchestrator artifacts (handoffs, stage results, checkpoints,
# decision logs) do not pollute the project's tracked tree or .gitignore.
#
# Mirrors multi-agent-loop's `ensure_git_exclude` (scripts/run_agent.sh:90-101).
# Per-clone exclude (not committed) — non-intrusive, no team-wide .gitignore edit.
#
# Usage:
#   ensure-workdir-exclude.sh [workdir]
#
# - `workdir` defaults to $PWD when omitted.
# - Silent no-op if `workdir` is not inside a git repo.
# - Idempotent: subsequent runs detect the existing entry and skip.
#
# Exit codes:
#   0 — exclude already present, or appended successfully, or non-git workdir
#   2 — workdir does not exist

set -euo pipefail

WORKDIR="${1:-$PWD}"

if [[ ! -d "$WORKDIR" ]]; then
  echo "workdir does not exist: $WORKDIR" >&2
  exit 2
fi

# Resolve to absolute path so `git -C` works regardless of caller cwd.
[[ "$WORKDIR" != /* ]] && WORKDIR="$PWD/$WORKDIR"

git_dir="$(git -C "$WORKDIR" rev-parse --absolute-git-dir 2>/dev/null || true)"
if [[ -z "$git_dir" ]]; then
  # Not a git repo — nothing to exclude. Silent success matches
  # multi-agent-loop's behavior (avoids forcing git on non-repo workdirs).
  exit 0
fi

exclude_file="$git_dir/info/exclude"
mkdir -p "$(dirname "$exclude_file")"

if ! grep -qxF '.spec-driven-dev/' "$exclude_file" 2>/dev/null; then
  echo '.spec-driven-dev/' >> "$exclude_file"
fi
