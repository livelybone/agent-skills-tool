#!/usr/bin/env bash
# check-review-results.sh
# Mechanical validation that content Stage Results have matching Review Results.
#
# Usage:
#   check-review-results.sh --checkpoint <path/to/workflow-checkpoint.md>
#   check-review-results.sh --self-test
#
# Exit codes:
#   0 — all checks pass
#   1 — usage error
#   2 — missing Stage Results section or Review Results entry for a content Stage Result
#   3 — malformed Review Results value

set -eo pipefail

CHECKPOINT=""
SELF_TEST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --checkpoint=*) CHECKPOINT="${1#*=}"; shift ;;
    --checkpoint)   CHECKPOINT="$2"; shift 2 ;;
    --self-test)    SELF_TEST=1; shift ;;
    -h|--help)
      sed -n '2,/^$/{s/^# //;s/^#//;p;}' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SELF_SCRIPT="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"

if [[ "$SELF_TEST" == "1" ]]; then
  ST_DIR=$(mktemp -d)
  trap 'rm -rf "$ST_DIR"' EXIT
  cd "$ST_DIR"

  fails=0
  run_case() {
    local name="$1" expected="$2" content="$3" actual
    echo "$content" > checkpoint.md
    set +e
    bash "$SELF_SCRIPT" --checkpoint checkpoint.md >/dev/null 2>&1
    actual=$?
    set -e
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }

  run_case "all reviewed" 0 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md
- \`orders/tech-spec\`: .spec-driven-dev/orders-epic/orders/tech-spec/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md
- \`orders/tech-spec\`: executed:.agent-loop/spec-review-orders/r1/agent-judgment.md

**Context Summary**:
- done" || ((fails++))

  run_case "standard complexity skip allowed" 0 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: skipped:Simple + user accepted manual review

**Context Summary**:
- done" || ((fails++))

  run_case "standard manual-only skip allowed" 0 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: controller-only
**Review Runner Policy**: manual-only

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: skipped:Simple + user accepted manual review without cross-agent runner

**Context Summary**:
- done" || ((fails++))

  run_case "manual-only rejects executed review" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: controller-only
**Review Runner Policy**: manual-only

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "duplicate review key rejected" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md
- \`single/modeling\`: skipped:Simple + duplicate should be rejected

**Context Summary**:
- blocked" || ((fails++))

  run_case "missing worker policy rejected" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "missing review runner policy rejected" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "clarification exempt" 0 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/clarification\`: .spec-driven-dev/single/single/clarification/stage-result.md
- \`single/tech-spec\`: .spec-driven-dev/single/single/tech-spec/stage-result.md

**Review Results**:
- \`single/tech-spec\`: executed:.agent-loop/spec-review-single/r1/agent-judgment.md

**Context Summary**:
- done" || ((fails++))

  run_case "missing review" 2 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/tech-spec\`: executed:.agent-loop/spec-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "malformed review value" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: maybe later

**Context Summary**:
- blocked" || ((fails++))

  run_case "missing stage results section" 2 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "auto mode rejects skipped review" 3 "# Workflow Checkpoint

**Run Mode**: auto
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed
**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: skipped:Simple + not allowed in auto

**Context Summary**:
- blocked" || ((fails++))

  run_case "auto mode requires subagent worker policy" 3 "# Workflow Checkpoint

**Run Mode**: auto
**Worker Execution Policy**: controller-only
**Review Runner Policy**: cross-agent-allowed
**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "auto mode requires cross-agent review policy" 3 "# Workflow Checkpoint

**Run Mode**: auto
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: manual-only
**Stage Results**:
- \`single/clarification\`: .spec-driven-dev/single/single/clarification/stage-result.md

**Review Results**:

**Context Summary**:
- blocked" || ((fails++))

  run_case "invalid run mode rejected" 3 "# Workflow Checkpoint

**Run Mode**: <standard | auto>
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed
**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "epic requires plan review" 2 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed
**Scope**: epic
**Stage Results**:
- \`_workflow/plan\`: .spec-driven-dev/my-epic/_workflow/plan/stage-result.md

**Review Results**:
- \`_workflow/modeling\`: executed:.agent-loop/modeling-review-_workflow/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "epic plan review cannot be skipped" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: cross-agent-allowed
**Scope**: epic

**Stage Results**:
- \`_workflow/plan\`: .spec-driven-dev/my-epic/_workflow/plan/stage-result.md

**Review Results**:
- \`_workflow/plan\`: skipped:Simple + plan review is mandatory

**Context Summary**:
- blocked" || ((fails++))

  run_case "invalid worker policy rejected" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: <subagent-allowed | controller-only>
**Review Runner Policy**: cross-agent-allowed
**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  run_case "invalid review runner policy rejected" 3 "# Workflow Checkpoint

**Run Mode**: standard
**Worker Execution Policy**: subagent-allowed
**Review Runner Policy**: <cross-agent-allowed | manual-only>
**Stage Results**:
- \`single/modeling\`: .spec-driven-dev/single/single/modeling/stage-result.md

**Review Results**:
- \`single/modeling\`: executed:.agent-loop/modeling-review-single/r1/agent-judgment.md

**Context Summary**:
- blocked" || ((fails++))

  exit "$fails"
fi

if [[ -z "$CHECKPOINT" || ! -f "$CHECKPOINT" ]]; then
  echo "Usage: $0 --checkpoint <workflow-checkpoint.md>" >&2
  exit 1
fi

extract_section() {
  local heading="$1"
  awk -v heading="$heading" '
    $0 == heading { in_section=1; next }
    in_section && /^\*\*/ { exit }
    in_section { print }
  ' "$CHECKPOINT"
}

extract_keys() {
  grep -E '^- `[^`]+`:' | sed -E 's/^- `([^`]+)`:.*$/\1/'
}

stage_keys=$(extract_section "**Stage Results**:" | extract_keys || true)
review_lines=$(extract_section "**Review Results**:" | grep -E '^- `[^`]+`:' || true)
run_mode=$(grep -E '^\*\*Run Mode\*\*:[[:space:]]*' "$CHECKPOINT" | head -n 1 | sed -E 's/^\*\*Run Mode\*\*:[[:space:]]*//' || true)
worker_execution_policy=$(grep -E '^\*\*Worker Execution Policy\*\*:[[:space:]]*' "$CHECKPOINT" | head -n 1 | sed -E 's/^\*\*Worker Execution Policy\*\*:[[:space:]]*//' || true)
review_runner_policy=$(grep -E '^\*\*Review Runner Policy\*\*:[[:space:]]*' "$CHECKPOINT" | head -n 1 | sed -E 's/^\*\*Review Runner Policy\*\*:[[:space:]]*//' || true)
scope=$(grep -E '^\*\*Scope\*\*:[[:space:]]*' "$CHECKPOINT" | head -n 1 | sed -E 's/^\*\*Scope\*\*:[[:space:]]*//' || true)

case "$run_mode" in
  standard|Standard|STANDARD) run_mode="standard" ;;
  auto|Auto|AUTO) run_mode="auto" ;;
  *)
    echo "Invalid or missing Run Mode in checkpoint" >&2
    exit 3
    ;;
esac

case "$worker_execution_policy" in
  subagent-allowed|subagent_allowed|Subagent-Allowed|SUBAGENT-ALLOWED) worker_execution_policy="subagent-allowed" ;;
  controller-only|controller_only|Controller-Only|CONTROLLER-ONLY) worker_execution_policy="controller-only" ;;
  *)
    echo "Invalid or missing Worker Execution Policy in checkpoint" >&2
    exit 3
    ;;
esac

case "$review_runner_policy" in
  cross-agent-allowed|cross_agent_allowed|Cross-Agent-Allowed|CROSS-AGENT-ALLOWED) review_runner_policy="cross-agent-allowed" ;;
  manual-only|manual_only|Manual-Only|MANUAL-ONLY) review_runner_policy="manual-only" ;;
  *)
    echo "Invalid or missing Review Runner Policy in checkpoint" >&2
    exit 3
    ;;
esac

if [[ "$run_mode" == "auto" && "$worker_execution_policy" != "subagent-allowed" ]]; then
  echo "Auto mode requires Worker Execution Policy 'subagent-allowed'" >&2
  exit 3
fi

if [[ "$run_mode" == "auto" && "$review_runner_policy" != "cross-agent-allowed" ]]; then
  echo "Auto mode requires Review Runner Policy 'cross-agent-allowed'" >&2
  exit 3
fi

case "$scope" in
  epic|Epic|EPIC) scope="epic" ;;
  single-module|single_module|single-module\ *|single_module\ *|"") scope="single-module" ;;
  *) scope="$scope" ;;
esac

if [[ -z "$stage_keys" ]]; then
  echo "No Stage Results entries found in checkpoint" >&2
  exit 2
fi

if [[ "$scope" == "epic" ]] && ! printf '%s\n' "$review_lines" | grep -Eq '^- `([^`]+/)?plan`:'; then
  echo "Missing Review Results entry for required Epic Plan Review" >&2
  exit 2
fi

while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  # Clarification intentionally has no independent review stage; downstream
  # modeling/spec review validates the clarified boundary.
  if [[ "$key" == */clarification ]]; then
    continue
  fi

  matching_lines=$(printf '%s\n' "$review_lines" |
    sed -n -E 's/^- `([^`]+)`:.*$/\1	&/p' |
    while IFS=$'\t' read -r review_key review_line; do
      if [[ "$review_key" == "$key" ]]; then
        printf '%s\n' "$review_line"
      fi
    done)
  if [[ -z "$matching_lines" ]]; then
    echo "Missing Review Results entry for Stage Results key: $key" >&2
    exit 2
  fi
  if [[ "$(printf '%s\n' "$matching_lines" | wc -l | tr -d '[:space:]')" != "1" ]]; then
    echo "Duplicate Review Results entries for key: $key" >&2
    exit 3
  fi
  line="$matching_lines"
  if [[ ! "$line" =~ ^-\ \`[^\`]+\`:\ (executed:[^[:space:]]|skipped:[^[:space:]]) ]]; then
    echo "Malformed Review Results entry for key: $key" >&2
    exit 3
  fi
  if [[ "$run_mode" == "auto" && "$line" =~ ^-\ \`[^\`]+\`:\ skipped: ]]; then
    echo "Auto mode cannot skip Review Results entry for key: $key" >&2
    exit 3
  fi
  if [[ "$review_runner_policy" == "manual-only" && "$line" =~ ^-\ \`[^\`]+\`:\ executed: ]]; then
    echo "Review Runner Policy 'manual-only' cannot use executed Review Results entry for key: $key" >&2
    exit 3
  fi
  if [[ "$scope" == "epic" && "$key" == */plan && "$line" =~ ^-\ \`[^\`]+\`:\ skipped: ]]; then
    echo "Epic Plan Review cannot be skipped for key: $key" >&2
    exit 3
  fi
done <<< "$stage_keys"

exit 0
