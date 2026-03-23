#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "usage: $0 <runner: codex|claude|crush|opencode> <task-name> <prompt-file> <role: agent|peer> [workdir]" >&2
  exit 2
fi

RUNNER="$1"
TASK_NAME="$2"
PROMPT_FILE="$3"
ROLE="$4"
WORKDIR="${5:-$PWD}"

if [[ ! -d "$WORKDIR" ]]; then
  echo "workdir does not exist: $WORKDIR" >&2
  exit 2
fi

TASK_DIR="$WORKDIR/.agent-loop/$TASK_NAME"

# 将 PROMPT_FILE 转为绝对路径，避免 cd "$WORKDIR" 后相对路径解析不一致
[[ "$PROMPT_FILE" != /* ]] && PROMPT_FILE="$PWD/$PROMPT_FILE"

case "$ROLE" in
  agent)
    OUTPUT_FILE="$TASK_DIR/agent-output.md"
    LOG_FILE="$TASK_DIR/agent.log"
    STATUS_FILE="$TASK_DIR/agent-status.txt"
    ;;
  peer)
    OUTPUT_FILE="$TASK_DIR/peer-output.md"
    LOG_FILE="$TASK_DIR/peer.log"
    STATUS_FILE="$TASK_DIR/peer-status.txt"
    ;;
  *)
    echo "unsupported role: $ROLE (must be agent or peer)" >&2
    # STATUS_FILE 未定义，无法写入 status；提前退出是安全的，
    # 因为 task dir 也未创建，controller 不会误判为"仍在运行"
    exit 2
    ;;
esac

mkdir -p "$TASK_DIR"
: > "$STATUS_FILE"

# 自动把 .agent-loop/ 加入本地 git exclude，避免污染 git status
GIT_DIR="$(git -C "$WORKDIR" rev-parse --git-dir 2>/dev/null || true)"
if [[ -n "$GIT_DIR" ]]; then
  EXCLUDE_FILE="$GIT_DIR/info/exclude"
  mkdir -p "$(dirname "$EXCLUDE_FILE")"
  if ! grep -qxF '.agent-loop/' "$EXCLUDE_FILE" 2>/dev/null; then
    echo '.agent-loop/' >> "$EXCLUDE_FILE"
  fi
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "prompt file not found: $PROMPT_FILE" >&2
  echo "error" > "$STATUS_FILE"
  exit 2
fi

run_codex() {
  (
    cd "$WORKDIR"
    codex exec \
      --sandbox workspace-write \
      -C "$WORKDIR" \
      -o "$OUTPUT_FILE" \
      - < "$PROMPT_FILE"
  ) > "$LOG_FILE" 2>&1
}

run_claude() {
  (
    cd "$WORKDIR"
    claude -p --output-format text < "$PROMPT_FILE"
  ) > "$OUTPUT_FILE" 2> "$LOG_FILE"
}

run_crush() {
  (
    cd "$WORKDIR"
    crush run -q -c "$WORKDIR" < "$PROMPT_FILE"
  ) > "$OUTPUT_FILE" 2> "$LOG_FILE"
}

run_opencode() {
  (
    cd "$WORKDIR"
    opencode run < "$PROMPT_FILE"
  ) > "$OUTPUT_FILE" 2> "$LOG_FILE"
}

case "$RUNNER" in
  codex)
    if run_codex; then
      echo "done" > "$STATUS_FILE"
      echo "done"
      exit 0
    fi
    ;;
  claude)
    if run_claude; then
      echo "done" > "$STATUS_FILE"
      echo "done"
      exit 0
    fi
    ;;
  crush)
    if run_crush; then
      echo "done" > "$STATUS_FILE"
      echo "done"
      exit 0
    fi
    ;;
  opencode)
    if run_opencode; then
      echo "done" > "$STATUS_FILE"
      echo "done"
      exit 0
    fi
    ;;
  *)
    echo "unsupported runner: $RUNNER" >&2
    echo "error" > "$STATUS_FILE"
    exit 2
    ;;
esac

echo "error" > "$STATUS_FILE"
echo "error"
exit 1
