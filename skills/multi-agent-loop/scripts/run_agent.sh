#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/prompt_protocol.sh"

DETACH_MODE="none"
PREPARED_STATUS_FILE=0
SKIP_JUDGMENT_CHECK=0
ALLOW_ROUND_OVERFLOW=0
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
    --allow-round-overflow)
      ALLOW_ROUND_OVERFLOW=1
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

if [[ $# -lt 3 ]]; then
  echo "usage: $0 [--detach=auto|tmux|none] [--skip-judgment-check] [--allow-round-overflow] <runner: codex|claude|crush|opencode> <task-name> <round-number> [workdir]" >&2
  exit 2
fi

RUNNER="$1"
TASK_NAME="$2"
ROUND="$3"
WORKDIR="${4:-$PWD}"
SELF_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# TASK_NAME 合法性校验：仅允许字母、数字、连字符、下划线、点（但不能是纯 "." 或 ".."）
if [[ ! "$TASK_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "invalid task-name: '$TASK_NAME' (must start with alphanumeric, only contain [a-zA-Z0-9._-])" >&2
  exit 2
fi

# ROUND 必须是正整数
if [[ ! "$ROUND" =~ ^[1-9][0-9]*$ ]]; then
  echo "invalid round-number: '$ROUND' (must be a positive integer)" >&2
  exit 2
fi

if [[ ! -d "$WORKDIR" ]]; then
  echo "workdir does not exist: $WORKDIR" >&2
  exit 2
fi

# 将 WORKDIR 转为绝对路径
[[ "$WORKDIR" != /* ]] && WORKDIR="$PWD/$WORKDIR"

TASK_DIR="$WORKDIR/.agent-loop/$TASK_NAME"
ROUND_DIR="$TASK_DIR/r$ROUND"
PROMPT_FILE="$TASK_DIR/agent-task.md"
OUTPUT_FILE="$ROUND_DIR/agent-output.md"
LOG_FILE="$ROUND_DIR/agent.log"
STATUS_FILE="$ROUND_DIR/agent-status.txt"

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

# Round-cap gate: 3 轮硬上限。超限时 controller 应在上层调整策略
# （拆分 scope / 降低单轮深度 / escalate 给用户），不要盲目加轮数。
# --allow-round-overflow 仅供调试与回归测试使用，日常流程不应依赖。
# 注意：此 gate 不因 --prepared-status-file 而旁路——detach 模式下 child
# 重跑 gate 与 parent 答案一致（ROUND 是纯参数），零成本换物理防御面。
if (( ROUND > 3 )) && [[ "$ALLOW_ROUND_OVERFLOW" -eq 0 ]]; then
  if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
    write_status "error"
  fi
  echo "round-cap gate: multi-agent-loop 硬上限 3 轮，当前 round=$ROUND 超限。" >&2
  echo "正当做法：在 controller 层调整策略——拆分 scope / 降低单轮深度 / escalate 给用户。" >&2
  echo "仅调试/测试场景可用 --allow-round-overflow 绕过。" >&2
  echo "详见 SKILL.md §「有界循环」终止条件。" >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
    write_status "error"
  fi
  echo "agent-task.md not found: $PROMPT_FILE" >&2
  echo "setup 阶段未完成——请先在 $TASK_DIR/ 下合成 agent-task.md 并通过 validate_task.sh 自检。" >&2
  exit 2
fi

if ! prompt_protocol_validate_prompt_file "$PROMPT_FILE"; then
  if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
    write_status "error"
  fi
  exit 2
fi

# Judgment gate: 启动新轮之前，同一 task-name 下所有已 done 的历史轮次必须
# 各自有 agent-judgment.md（controller 逐条独立重评的产物）。这是 SKILL.md
# §「controller 裁决与 judgment 文件」的物理门，用来对抗 autopilot Critical-fixing。
# --skip-judgment-check 仅用于历史清理、自动化测试等非日常场景。
# 注意：此 gate 不因 --prepared-status-file 而旁路——detach 模式下 child
# 重跑 gate 与 parent 答案一致（其他轮次状态在 parent→child 期间不变），
# 零成本换物理防御面，避免 --prepared-status-file 被当成隐藏绕过入口。
if [[ "$SKIP_JUDGMENT_CHECK" -eq 0 ]]; then
  missing_judgments=()
  if [[ -d "$TASK_DIR" ]]; then
    for existing_round_dir in "$TASK_DIR"/r*/; do
      [[ -d "$existing_round_dir" ]] || continue
      existing_round_name="$(basename "$existing_round_dir")"
      # 跳过当前轮自身（允许同轮重跑清理后重新启动）
      [[ "$existing_round_name" == "r$ROUND" ]] && continue
      existing_status_file="${existing_round_dir}agent-status.txt"
      existing_output_file="${existing_round_dir}agent-output.md"
      existing_judgment_file="${existing_round_dir}agent-judgment.md"
      if [[ -f "$existing_status_file" && -f "$existing_output_file" ]]; then
        existing_status_content="$(< "$existing_status_file")"
        if [[ "$existing_status_content" == "done" && ( ! -s "$existing_judgment_file" ) ]]; then
          missing_judgments+=("$existing_judgment_file")
        fi
      fi
    done
  fi
  if (( ${#missing_judgments[@]} > 0 )); then
    if [[ "$PREPARED_STATUS_FILE" -eq 1 && -f "$STATUS_FILE" ]]; then
      write_status "error"
    fi
    echo "judgment gate: cannot launch new round while prior rounds in '$TASK_NAME' lack a controller judgment." >&2
    echo "Missing judgment files:" >&2
    for f in "${missing_judgments[@]}"; do
      echo "  - $f" >&2
    done
    echo "Write one line per finding in each missing file, format:" >&2
    echo "  [<id>] agent:<Severity> → controller:<Severity>  reason: <one-line justification>" >&2
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
    echo "round $ROUND already has artifacts under $ROUND_DIR (use a new round-number or clean up first)" >&2
    exit 2
  fi

  mkdir -p "$ROUND_DIR"
  : > "$STATUS_FILE"
  trap finalize_prelaunch_status EXIT
  ensure_git_exclude

  DETACH_SESSION="agent-loop-${TASK_NAME//[^a-zA-Z0-9_.-]/-}-r${ROUND}-$$"
  # 透传 parent 上用户显式传入的 gate-bypass flag 到 child——否则 child 重跑 gate 时会
  # 与 parent 判定不一致（parent 跳过、child 拦掉），导致推荐的 detach 模式下
  # --skip-judgment-check / --allow-round-overflow 失效。
  detach_args=("$SELF_PATH" "--prepared-status-file")
  if [[ "$SKIP_JUDGMENT_CHECK" -eq 1 ]]; then
    detach_args+=("--skip-judgment-check")
  fi
  if [[ "$ALLOW_ROUND_OVERFLOW" -eq 1 ]]; then
    detach_args+=("--allow-round-overflow")
  fi
  detach_args+=("$RUNNER" "$TASK_NAME" "$ROUND" "$WORKDIR")
  DETACH_CMD="$(printf '%q ' "${detach_args[@]}")"
  if ! tmux new-session -d -s "$DETACH_SESSION" "cd $(printf '%q' "$WORKDIR") && exec ${DETACH_CMD% }"; then
    write_status "error"
    exit 1
  fi
  trap - EXIT
  echo "detached:$DETACH_SESSION"
  exit 0
fi

mkdir -p "$ROUND_DIR"

# 同一 round 只允许执行一次，避免后续轮次静默覆盖前一轮产物。
if [[ "$PREPARED_STATUS_FILE" -eq 1 ]]; then
  if [[ -e "$OUTPUT_FILE" || -e "$LOG_FILE" ]]; then
    write_status "error"
    echo "round $ROUND already has artifacts under $ROUND_DIR (use a new round-number or clean up first)" >&2
    exit 2
  fi
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "prepared status file missing for detached child: $STATUS_FILE" >&2
    exit 2
  fi
else
  if [[ -e "$OUTPUT_FILE" || -e "$LOG_FILE" || -e "$STATUS_FILE" ]]; then
    echo "round $ROUND already has artifacts under $ROUND_DIR (use a new round-number or clean up first)" >&2
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
