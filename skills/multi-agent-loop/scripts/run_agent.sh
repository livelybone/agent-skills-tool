#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/prompt_protocol.sh"

DETACH_MODE="none"
PREPARED_STATUS_FILE=0
SKIP_JUDGMENT_CHECK=0
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --prepared-status-file)
      PREPARED_STATUS_FILE=1
      shift
      ;;
    --skip-judgment-check)
      SKIP_JUDGMENT_CHECK=1
      shift
      ;;
    --detach=*)
      DETACH_MODE="${1#--detach=}"
      shift
      ;;
    --detach)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --detach (expected auto|tmux|none)" >&2
        exit 2
      fi
      DETACH_MODE="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

case "$DETACH_MODE" in
  auto|tmux|none)
    ;;
  *)
    echo "unsupported detach mode: $DETACH_MODE (must be auto, tmux, or none)" >&2
    exit 2
    ;;
esac

if [[ $# -lt 4 ]]; then
  echo "usage: $0 [--detach=auto|tmux|none] [--skip-judgment-check] <runner: codex|claude|crush|opencode> <task-name> <prompt-file> <role: agent|peer> [workdir]" >&2
  exit 2
fi

RUNNER="$1"
TASK_NAME="$2"
PROMPT_FILE="$3"
ROLE="$4"
WORKDIR="${5:-$PWD}"
SELF_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# TASK_NAME 合法性校验：仅允许字母、数字、连字符、下划线、点（但不能是纯 "." 或 ".."）
if [[ ! "$TASK_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "invalid task-name: '$TASK_NAME' (must start with alphanumeric, only contain [a-zA-Z0-9._-])" >&2
  exit 2
fi

if [[ ! -d "$WORKDIR" ]]; then
  echo "workdir does not exist: $WORKDIR" >&2
  exit 2
fi

# 将 WORKDIR 转为绝对路径
[[ "$WORKDIR" != /* ]] && WORKDIR="$PWD/$WORKDIR"

TASK_DIR="$WORKDIR/.agent-loop/$TASK_NAME"

# 将 PROMPT_FILE 转为绝对路径，基于 WORKDIR 而非 PWD
if [[ "$PROMPT_FILE" != /* ]]; then
  PROMPT_FILE="$WORKDIR/$PROMPT_FILE"
fi

case "$ROLE" in
  agent)
    EXPECTED_PROMPT_FILE="$TASK_DIR/agent-task.md"
    OUTPUT_FILE="$TASK_DIR/agent-output.md"
    LOG_FILE="$TASK_DIR/agent.log"
    STATUS_FILE="$TASK_DIR/agent-status.txt"
    ;;
  peer)
    EXPECTED_PROMPT_FILE="$TASK_DIR/peer-task.md"
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

ensure_git_exclude() {
  local git_dir exclude_file

  git_dir="$(git -C "$WORKDIR" rev-parse --absolute-git-dir 2>/dev/null || true)"
  if [[ -n "$git_dir" ]]; then
    exclude_file="$git_dir/info/exclude"
    mkdir -p "$(dirname "$exclude_file")"
    if ! grep -qxF '.agent-loop/' "$exclude_file" 2>/dev/null; then
      echo '.agent-loop/' >> "$exclude_file"
    fi
  fi
}

STATUS_WRITTEN=0

write_status() {
  local value="$1"
  printf '%s\n' "$value" > "$STATUS_FILE"
  STATUS_WRITTEN=1
}

finalize_prelaunch_status() {
  local exit_code=$?
  if [[ ${STATUS_WRITTEN:-0} -eq 0 && $exit_code -ne 0 ]]; then
    write_status "error"
  fi
  exit "$exit_code"
}

case "$RUNNER" in
  codex|claude|crush|opencode)
    ;;
  *)
    echo "unsupported runner: $RUNNER" >&2
    exit 2
    ;;
esac

# Round-cap gate: hard cap at 3 rounds for <step>-<module>-r<N> tasks; see SKILL.md §「有界循环」.
if [[ "$ROLE" == "agent" && "$PREPARED_STATUS_FILE" -eq 0 ]]; then
  if [[ "$TASK_NAME" =~ -r([0-9]+)$ ]]; then
    round_num="${BASH_REMATCH[1]}"
    if (( round_num > 3 )); then
      echo "round-cap gate: multi-agent-loop 硬上限 3 轮，task-name '$TASK_NAME' 超限（N=$round_num）。" >&2
      echo "无 override 入口（刻意设计）。需要继续时在 controller 层调整策略：拆分 scope / 降低单轮深度 / escalate 给用户。" >&2
      echo "详见 SKILL.md §「有界循环」终止条件。" >&2
      exit 2
    fi
  fi
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
    write_status "error"
  fi
  echo "prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

if [[ "$PROMPT_FILE" != "$EXPECTED_PROMPT_FILE" ]]; then
  if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
    write_status "error"
  fi
  echo "prompt file must be canonical for task/role: expected $EXPECTED_PROMPT_FILE, got $PROMPT_FILE" >&2
  exit 2
fi

if ! prompt_protocol_validate_prompt_file "$PROMPT_FILE" "$ROLE"; then
  if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
    write_status "error"
  fi
  exit 2
fi

# Judgment gate: before launching a new agent round, every previously
# completed agent or peer run in this workdir must have its own written
# judgment file (agent-judgment.md for agent findings, peer-judgment.md
# for peer findings) capturing the controller's re-evaluation. This is
# the forcing function against "autopilot Critical-fixing"—see SKILL.md.
# Only enforced on fresh agent launches (peer reruns stay within a task).
# Use --skip-judgment-check to bypass for historical cleanup or unit tests.
if [[ "$ROLE" == "agent" && "$SKIP_JUDGMENT_CHECK" -eq 0 && "$PREPARED_STATUS_FILE" -eq 0 ]]; then
  missing_judgments=()
  loop_dir="$WORKDIR/.agent-loop"
  if [[ -d "$loop_dir" ]]; then
    for existing_task_dir in "$loop_dir"/*/; do
      [[ -d "$existing_task_dir" ]] || continue
      existing_task_name="$(basename "$existing_task_dir")"
      [[ "$existing_task_name" == "$TASK_NAME" ]] && continue
      for sub_role in agent peer; do
        status_file="${existing_task_dir}${sub_role}-status.txt"
        output_file="${existing_task_dir}${sub_role}-output.md"
        judgment_file="${existing_task_dir}${sub_role}-judgment.md"
        if [[ -f "$status_file" && -f "$output_file" ]]; then
          status_content="$(< "$status_file")"
          if [[ "$status_content" == "done" && ( ! -s "$judgment_file" ) ]]; then
            missing_judgments+=("$judgment_file")
          fi
        fi
      done
    done
  fi
  if (( ${#missing_judgments[@]} > 0 )); then
    echo "judgment gate: cannot launch new task while prior runs lack a controller judgment." >&2
    echo "Missing judgment files:" >&2
    for f in "${missing_judgments[@]}"; do
      echo "  - $f" >&2
    done
    echo "Write one line per finding in each missing file, format:" >&2
    echo "  [<id>] <agent|peer>:<Severity> → controller:<Severity>  reason: <one-line justification>" >&2
    echo "See SKILL.md §「controller 裁决与 judgment 文件」 for details." >&2
    echo "Pass --skip-judgment-check to bypass (e.g., for historical cleanup)." >&2
    exit 2
  fi
fi

if [[ "$DETACH_MODE" == "auto" ]]; then
  if command -v tmux >/dev/null 2>&1; then
    DETACH_MODE="tmux"
  else
    DETACH_MODE="none"
  fi
fi

if [[ "$DETACH_MODE" == "tmux" ]]; then
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found: detach=tmux unavailable" >&2
    exit 2
  fi

  if [[ -e "$OUTPUT_FILE" || -e "$LOG_FILE" || -e "$STATUS_FILE" ]]; then
    echo "task-name already has $ROLE artifacts: $TASK_NAME (use a unique task-name per round)" >&2
    exit 2
  fi

  mkdir -p "$TASK_DIR"
  : > "$STATUS_FILE"
  trap finalize_prelaunch_status EXIT
  ensure_git_exclude

  DETACH_SESSION="agent-loop-${TASK_NAME//[^a-zA-Z0-9_.-]/-}-$$"
  DETACH_CMD="$(printf '%q ' "$SELF_PATH" "--prepared-status-file" "$RUNNER" "$TASK_NAME" "$PROMPT_FILE" "$ROLE" "$WORKDIR")"
  if ! tmux new-session -d -s "$DETACH_SESSION" "cd $(printf '%q' "$WORKDIR") && exec ${DETACH_CMD% }"; then
    write_status "error"
    exit 1
  fi
  trap - EXIT
  echo "detached:$DETACH_SESSION"
  exit 0
fi

mkdir -p "$TASK_DIR"

# 同一 task-name + role 只允许执行一次，避免后续轮次静默覆盖前一轮产物。
if [[ "$PREPARED_STATUS_FILE" -eq 1 ]]; then
  if [[ -e "$OUTPUT_FILE" || -e "$LOG_FILE" ]]; then
    write_status "error"
    echo "task-name already has $ROLE artifacts: $TASK_NAME (use a unique task-name per round)" >&2
    exit 2
  fi
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "prepared status file missing for detached child: $STATUS_FILE" >&2
    exit 2
  fi
else
  if [[ -e "$OUTPUT_FILE" || -e "$LOG_FILE" || -e "$STATUS_FILE" ]]; then
    echo "task-name already has $ROLE artifacts: $TASK_NAME (use a unique task-name per round)" >&2
    exit 2
  fi
  : > "$STATUS_FILE"
fi

finalize_status() {
  local exit_code=$?
  if [[ ${STATUS_WRITTEN:-0} -eq 0 ]]; then
    if [[ $exit_code -eq 0 ]]; then
      write_status "done"
    else
      write_status "error"
    fi
  fi
  exit "$exit_code"
}

trap finalize_status EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

ensure_git_exclude

run_codex() {
  # 预清空输出文件，与 claude/crush/opencode 的 > 重定向行为对称
  : > "$OUTPUT_FILE"
  (
    cd "$WORKDIR"
    codex exec \
      --sandbox danger-full-access \
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
      write_status "done"
      echo "done"
      exit 0
    fi
    ;;
  claude)
    if run_claude; then
      write_status "done"
      echo "done"
      exit 0
    fi
    ;;
  crush)
    if run_crush; then
      write_status "done"
      echo "done"
      exit 0
    fi
    ;;
  opencode)
    if run_opencode; then
      write_status "done"
      echo "done"
      exit 0
    fi
    ;;
esac

write_status "error"
echo "error"
exit 1
