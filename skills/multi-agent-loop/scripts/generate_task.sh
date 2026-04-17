#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/prompt_protocol.sh"

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <type> <task-name> <role> < instructions.md" >&2
  echo "instructions are always read from stdin" >&2
  exit 2
fi

PROMPT_TYPE="$1"
TASK_NAME="$2"
PROMPT_ROLE="$3"
WORKDIR="${PWD}"

if [[ ! "$TASK_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "invalid task-name: '$TASK_NAME' (must start with alphanumeric, only contain [a-zA-Z0-9._-])" >&2
  exit 2
fi

case "$PROMPT_ROLE" in
  agent)
    OUTPUT_FILE="$WORKDIR/.agent-loop/$TASK_NAME/agent-task.md"
    ;;
  peer)
    OUTPUT_FILE="$WORKDIR/.agent-loop/$TASK_NAME/peer-task.md"
    ;;
  *)
    echo "unsupported role: $PROMPT_ROLE (must be agent or peer)" >&2
    exit 2
    ;;
esac

prompt_protocol_render_prompt_stdin "$PROMPT_TYPE" "$PROMPT_ROLE" "$OUTPUT_FILE"
