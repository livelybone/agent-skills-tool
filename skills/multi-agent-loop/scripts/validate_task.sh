#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/prompt_protocol.sh"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <task-name> <role: agent|peer> [workdir]" >&2
  exit 2
fi

TASK_NAME="$1"
ROLE="$2"
WORKDIR="${3:-$PWD}"

if [[ ! "$TASK_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "invalid task-name: '$TASK_NAME' (must start with alphanumeric, only contain [a-zA-Z0-9._-])" >&2
  exit 2
fi

if [[ ! -d "$WORKDIR" ]]; then
  echo "workdir does not exist: $WORKDIR" >&2
  exit 2
fi

[[ "$WORKDIR" != /* ]] && WORKDIR="$PWD/$WORKDIR"

case "$ROLE" in
  agent)
    PROMPT_FILE="$WORKDIR/.agent-loop/$TASK_NAME/agent-task.md"
    ;;
  peer)
    PROMPT_FILE="$WORKDIR/.agent-loop/$TASK_NAME/peer-task.md"
    ;;
  *)
    echo "unsupported role: $ROLE (must be agent or peer)" >&2
    exit 2
    ;;
esac

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

prompt_protocol_validate_prompt_file "$PROMPT_FILE" "$ROLE"
echo "ok: $PROMPT_FILE"
