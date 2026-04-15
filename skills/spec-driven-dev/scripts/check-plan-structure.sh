#!/usr/bin/env bash
# check-plan-structure.sh
# Mechanical validation of Epic plan.md structural hard constraints.
#
# Checks (all are HARD FAILS — any failure → non-zero exit):
#   1. Each Aggregate anchor appears in exactly one module's "持有聚合" field
#      (forbids aggregates being split across modules).
#   2. Every "模块依赖" and "产出契约" upstream-ref uses a Rel.* anchor
#      (forbids fabricating cross-module contracts that don't map to a
#      cross-module relationship declared in the upstream modeling unit).
#   3. Every "持有聚合" upstream-ref uses an Aggregate.* anchor.
#   4. Every Aggregate.* anchor declared in the listed upstream modeling
#      units is "held" by at least one plan module (ONLY enforced when
#      --upstream is provided; plan-internal checks 1-3 still run without it).
#
# Path convention (modeling-first v0.3+):
#   upstream-refs point to `<path>/<scenario>/<name>.md#<Namespace>.<Name>`
#   where scenario ∈ {domain, ui, components, process, state-machine}.
#   Aggregates live in `domain/` units; Rel anchors are declared in the
#   referring module's unit (see modeling-first cross-module contract hints).
#
# Anchor existence against the upstream modeling units is validated by
# check-upstream-coverage.sh; this script focuses on Plan-specific
# structural constraints and (optionally, with --upstream) aggregate
#落位 coverage.
#
# Usage:
#   check-plan-structure.sh --plan <path/to/plan.md> [--upstream <path>,...]
#   check-plan-structure.sh --self-test
#
# Exit codes:
#   0 — all checks pass
#   1 — usage error
#   2 — Check 1 failed (aggregate appears in multiple modules)
#   3 — Check 2 failed (模块依赖/产出契约 references a non-Rel anchor)
#   4 — Check 3 failed (持有聚合 references a non-Aggregate anchor)
#   5 — Check 4 failed (aggregate declared in upstream but not held by any plan module)

set -eo pipefail

PLAN=""
UPSTREAMS=""
SELF_TEST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan=*)        PLAN="${1#*=}"; shift ;;
    --plan)          PLAN="$2"; shift 2 ;;
    --upstream=*)    UPSTREAMS="${1#*=}"; shift ;;
    --upstream)      UPSTREAMS="$2"; shift 2 ;;
    --self-test)     SELF_TEST=1; shift ;;
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

SELF_SCRIPT="$(readlink -f "$0")"

# Anchor extraction regex: path ending with <scenario>/<name>.md, then `#`,
# then PascalCase namespace + "." + name. Aligned with check-upstream-coverage.sh.
# modeling-first v0.3+ retired the `model.md`/`epic-model.md` basename
# convention; the script only accepts scenario-qualified paths.
SCENARIO_ALT='domain|ui|components|process|state-machine'
UNIT_NAME_RE='[a-z0-9][a-z0-9-]*'
ANCHOR_RE="(${SCENARIO_ALT})/${UNIT_NAME_RE}\\.md#[A-Z][A-Za-z0-9]*\\.[A-Za-z0-9._-]+"

# ── Self-test ──────────────────────────────────────────────
if [[ "$SELF_TEST" == "1" ]]; then
  ST_DIR=$(mktemp -d)
  trap 'rm -rf "$ST_DIR"' EXIT
  cd "$ST_DIR"

  fails=0
  run_case() {
    local name="$1"; local expected="$2"; local content="$3"
    echo "$content" > plan.md
    local actual
    bash "$SELF_SCRIPT" --plan plan.md >/dev/null 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }

  # Case: clean plan passes
  run_case "clean plan (2 modules, disjoint aggregates, Rel-typed contracts)" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **边界**：订单生命周期
- **模块依赖**：无
- **产出契约**：订单事件 (upstream-ref: docs/models/domain/order.md#Rel.Order-User)
- **复杂度**：Medium

## Module: payment
- **持有聚合**：Payment (upstream-ref: docs/models/domain/payment.md#Aggregate.Payment)
- **边界**：支付
- **模块依赖**：order 的订单事件 (upstream-ref: docs/models/domain/order.md#Rel.Order-Payment)
- **产出契约**：支付回执 (upstream-ref: docs/models/domain/payment.md#Rel.Payment-Order)
- **复杂度**：Simple" || ((fails++))

  # Case: short-path refs (scenario/name.md without docs/models/ prefix) also work
  run_case "clean plan with short-path refs" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：订单事件 (upstream-ref: domain/order.md#Rel.Order-User)" || ((fails++))

  # Case: aggregate split across modules → Check 1 fails
  run_case "aggregate split across two modules" 2 "# Plan

## Module: order-write
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)

## Module: order-read
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)" || ((fails++))

  # Case: 模块依赖 uses Aggregate.* instead of Rel.* → Check 2 fails
  run_case "module dependency uses Aggregate anchor instead of Rel" 3 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：user 的 User 聚合 (upstream-ref: docs/models/domain/user.md#Aggregate.User)
- **产出契约**：无" || ((fails++))

  # Case: 产出契约 uses Entity.* instead of Rel.* → Check 2 fails
  run_case "output contract uses Entity anchor instead of Rel" 3 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：订单实体快照 (upstream-ref: docs/models/domain/order.md#Entity.Order)" || ((fails++))

  # Case: 持有聚合 uses Rel.* instead of Aggregate.* → Check 3 fails
  run_case "holding aggregate uses Rel anchor instead of Aggregate" 4 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Rel.Order-User)
- **模块依赖**：无
- **产出契约**：无" || ((fails++))

  # Case: no aggregate (pure coordination module) is allowed
  run_case "pure coordination module with no aggregate is allowed" 0 "# Plan

## Module: orchestrator
- **持有聚合**：无聚合，纯派生/协调逻辑
- **模块依赖**：order 的订单事件 (upstream-ref: docs/models/domain/order.md#Rel.Order-Orchestrator)
- **产出契约**：无
- **复杂度**：Simple" || ((fails++))

  # Case: multiple aggregates in one module, all distinct → allowed
  run_case "module holding multiple distinct aggregates is allowed" 0 "# Plan

## Module: order-payment
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order), Payment (upstream-ref: docs/models/domain/payment.md#Aggregate.Payment)
- **模块依赖**：无
- **产出契约**：无" || ((fails++))

  # Case: Progress table and Dependency Graph sections are ignored
  run_case "Progress table and Dependency Graph ignored (no false positives)" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：无

## Dependency Graph

## Progress

| 模块 | 步骤 | 状态 | 备注 |
|------|------|------|------|
| order | — | pending | |" || ((fails++))

  # Case: N/A is allowed in 模块依赖 / 产出契约
  run_case "N/A allowed in dependency / contract fields" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：N/A
- **产出契约**：N/A" || ((fails++))

  # Case: process/ scenario Rel.* refs are valid for 模块依赖 / 产出契约
  # (modeling-first v0.3+ allows process units to hold Rel anchors too).
  run_case "process/ scenario Rel.* accepted for module dependency" 0 "# Plan

## Module: refund
- **持有聚合**：无聚合，纯派生/协调逻辑
- **模块依赖**：order 的退款触发事件 (upstream-ref: docs/models/process/refund.md#Rel.Refund-Order)
- **产出契约**：退款完成回执 (upstream-ref: docs/models/process/refund.md#Rel.Refund-Payment)
- **复杂度**：Medium" || ((fails++))

  # Case: mixed domain + process Rel.* in the same plan is allowed
  run_case "mixed domain + process Rel.* refs in one plan" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：订单事件 (upstream-ref: docs/models/domain/order.md#Rel.Order-Refund)
- **复杂度**：Simple

## Module: refund
- **持有聚合**：无聚合，纯派生/协调逻辑
- **模块依赖**：order 的订单事件 (upstream-ref: docs/models/domain/order.md#Rel.Order-Refund)
- **产出契约**：退款流程回执 (upstream-ref: docs/models/process/refund.md#Rel.Refund-Order)
- **复杂度**：Medium" || ((fails++))

  # Case: cross-scenario same-name refs (domain/orders + ui/orders) don't
  # accidentally collide at the Plan level — each unit has its own identity.
  # Here only domain/orders.md holds Aggregate; ui/orders.md never appears in
  # the plan (UI units are not cross-module contract sources).
  run_case "cross-scenario same-name identities treated distinctly" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/orders.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：订单事件 (upstream-ref: docs/models/domain/orders.md#Rel.Order-User)
- **复杂度**：Medium" || ((fails++))

  # ── Check 4 self-tests (require --upstream; isolate via a fresh helper) ──
  run_case_upstream() {
    local name="$1"; local expected="$2"; local plan_content="$3"; local upstream_args="$4"
    echo "$plan_content" > plan.md
    local actual
    bash "$SELF_SCRIPT" --plan plan.md --upstream "$upstream_args" >/dev/null 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }
  mkdir -p docs/models/domain
  cat > docs/models/domain/order.md <<'EOF_UP_ORDER'
<!-- anchor: Aggregate.Order -->
- Order aggregate
<!-- anchor: Rel.Order-Payment -->
- Order references Payment
EOF_UP_ORDER
  cat > docs/models/domain/payment.md <<'EOF_UP_PAY'
<!-- anchor: Aggregate.Payment -->
- Payment aggregate
EOF_UP_PAY

  # Case: all upstream aggregates are held → Check 4 passes
  run_case_upstream "all upstream aggregates held (with --upstream)" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：订单到支付事件 (upstream-ref: docs/models/domain/order.md#Rel.Order-Payment)

## Module: payment
- **持有聚合**：Payment (upstream-ref: docs/models/domain/payment.md#Aggregate.Payment)
- **模块依赖**：无
- **产出契约**：无" \
    "docs/models/domain/order.md,docs/models/domain/payment.md" || ((fails++))

  # Case: one upstream aggregate missing from plan → Check 4 fails (exit 5)
  run_case_upstream "missing aggregate in plan triggers Check 4" 5 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：无" \
    "docs/models/domain/order.md,docs/models/domain/payment.md" || ((fails++))

  # Case: --upstream with invalid path rejected at exit 1
  run_case_upstream "--upstream path must be scenario-qualified" 1 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：无" \
    "model.md" || ((fails++))

  # Case: short-path plan refs still match full-path upstream identity
  run_case_upstream "short-path plan refs match full-path upstream" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：无

## Module: payment
- **持有聚合**：Payment (upstream-ref: domain/payment.md#Aggregate.Payment)
- **模块依赖**：无
- **产出契约**：无" \
    "docs/models/domain/order.md,docs/models/domain/payment.md" || ((fails++))

  # Case: without --upstream, missing-aggregate is NOT enforced (backwards compat)
  run_case "without --upstream, Check 4 is skipped (plan-internal only)" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: docs/models/domain/order.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：无" || ((fails++))

  # Case: legacy (epic-)model.md basename refs are not picked up by the
  # scenario-qualified regex. This makes legacy plans loudly invalid (no
  # aggregate refs detected → any 模块依赖/产出契约 that DO match the new
  # regex will trigger their checks; if none do, the plan technically
  # "passes" with no constraints — but that's caught elsewhere by
  # check-upstream-coverage.sh which will reject the legacy basename).
  # Exercise: a plan that mixes legacy basename for 持有聚合 (not detected)
  # with a scenario-qualified Rel ref for 模块依赖 (detected) — plan is
  # effectively missing its aggregate declaration; but this script doesn't
  # require 持有聚合 to be declared (some coordination modules have none),
  # so exit 0. Legacy references are caught downstream by
  # check-upstream-coverage.sh.
  run_case "legacy basename refs are ignored by plan-structure (caught elsewhere)" 0 "# Plan

## Module: order
- **持有聚合**：Order (upstream-ref: epic-model.md#Aggregate.Order)
- **模块依赖**：无
- **产出契约**：无" || ((fails++))

  echo ""
  if [[ $fails -eq 0 ]]; then
    echo "=== Self-test: ALL PASSED ==="
    exit 0
  else
    echo "=== Self-test: $fails FAILURE(S) ==="
    exit 1
  fi
fi

# ── Normal run ─────────────────────────────────────────────
if [[ -z "$PLAN" ]]; then
  echo "Error: --plan <path> is required" >&2
  echo "Run with --help for usage" >&2
  exit 1
fi

if [[ ! -f "$PLAN" ]]; then
  echo "Error: plan file not found: $PLAN" >&2
  exit 1
fi

# Parse plan.md into per-module blocks. A module block starts at `## Module:`
# and ends at the next top-level section (`## ` or `---` boundary or EOF).
# Structural sections `## Dependency Graph`, `## Progress`, and everything
# after `## Plan 硬约束自检` are ignored.

EXTRACT_DIR=$(mktemp -d)
trap 'rm -rf "$EXTRACT_DIR"' EXIT

awk -v out="$EXTRACT_DIR" '
  BEGIN { mod = ""; idx = 0 }
  /^## Module:[[:space:]]*/ {
    idx++
    mod_name = $0
    sub(/^## Module:[[:space:]]*/, "", mod_name)
    mod = sprintf("%s/module-%03d.txt", out, idx)
    print "MODULE_NAME:" mod_name > mod
    next
  }
  /^## / && mod != "" { mod = ""; next }
  /^---/ && mod != "" { mod = ""; next }
  mod != "" { print $0 >> mod }
' "$PLAN"

# Collect aggregates declared across all modules.
# Format in AGG_FILE: <module-name>\t<anchor>
AGG_FILE="$EXTRACT_DIR/aggregates.tsv"
: > "$AGG_FILE"
# DEP_FILE: refs from 模块依赖
DEP_FILE="$EXTRACT_DIR/deps.tsv"
: > "$DEP_FILE"
# OUT_FILE: refs from 产出契约
OUT_FILE="$EXTRACT_DIR/outputs.tsv"
: > "$OUT_FILE"

for f in "$EXTRACT_DIR"/module-*.txt; do
  [[ -f "$f" ]] || continue
  mod_name=$(head -n1 "$f" | sed 's/^MODULE_NAME://')
  # Extract the 持有聚合 / 模块依赖 / 产出契约 lines.
  # Each field may span multiple anchors (comma-separated).
  while IFS= read -r line; do
    case "$line" in
      *"持有聚合"*)
        # All anchor tokens on this line.
        while IFS= read -r ref; do
          [[ -z "$ref" ]] && continue
          echo -e "${mod_name}\t${ref}" >> "$AGG_FILE"
        done < <(echo "$line" | grep -oE "$ANCHOR_RE" || true)
        ;;
      *"模块依赖"*)
        while IFS= read -r ref; do
          [[ -z "$ref" ]] && continue
          echo -e "${mod_name}\t${ref}" >> "$DEP_FILE"
        done < <(echo "$line" | grep -oE "$ANCHOR_RE" || true)
        ;;
      *"产出契约"*)
        while IFS= read -r ref; do
          [[ -z "$ref" ]] && continue
          echo -e "${mod_name}\t${ref}" >> "$OUT_FILE"
        done < <(echo "$line" | grep -oE "$ANCHOR_RE" || true)
        ;;
    esac
  done < "$f"
done

fail=0

# ── Check 3: 持有聚合 anchor must be Aggregate.* ───────────
BAD_AGG_TYPE=$(awk -F'\t' '$2 !~ /#Aggregate\./ { print }' "$AGG_FILE" || true)
if [[ -n "$BAD_AGG_TYPE" ]]; then
  echo "❌ Check 3 FAILED: 持有聚合 field must reference an Aggregate.* anchor" >&2
  echo "$BAD_AGG_TYPE" | while IFS=$'\t' read -r mod ref; do
    echo "  - module [$mod]: $ref" >&2
  done
  fail=4
fi

# ── Check 1: each Aggregate anchor appears in exactly one module ──
DUP_AGG=$(awk -F'\t' '$2 ~ /#Aggregate\./ { print $2 }' "$AGG_FILE" | sort | uniq -d || true)
if [[ -n "$DUP_AGG" ]]; then
  echo "❌ Check 1 FAILED: Aggregate appears in multiple modules (forbidden — aggregate cannot be split)" >&2
  echo "$DUP_AGG" | while read -r a; do
    [[ -z "$a" ]] && continue
    owners=$(awk -F'\t' -v a="$a" '$2 == a { print $1 }' "$AGG_FILE" | tr '\n' ',' | sed 's/,$//')
    echo "  - $a → owned by: $owners" >&2
  done
  fail=2
fi

# ── Check 2: 模块依赖 / 产出契约 must be Rel.* ─────────────
BAD_DEP=$(awk -F'\t' '$2 !~ /#Rel\./ { print "dep\t"$0 }' "$DEP_FILE" || true)
BAD_OUT=$(awk -F'\t' '$2 !~ /#Rel\./ { print "contract\t"$0 }' "$OUT_FILE" || true)
BAD_CROSS="${BAD_DEP}${BAD_OUT:+$'\n'}${BAD_OUT}"
if [[ -n "$BAD_DEP" || -n "$BAD_OUT" ]]; then
  echo "❌ Check 2 FAILED: 模块依赖 / 产出契约 must reference a Rel.* anchor (cross-module relationship declared in the referring module's modeling unit)" >&2
  printf "%s\n" "$BAD_CROSS" | while IFS=$'\t' read -r kind mod ref; do
    [[ -z "$ref" ]] && continue
    echo "  - [$kind] module [$mod]: $ref" >&2
  done
  # Check 2 takes precedence over Check 1 only if Check 1 didn't already fail.
  [[ $fail -eq 0 ]] && fail=3
fi

# ── Check 4 (optional): every upstream Aggregate.* is held by some module ──
# Only runs when --upstream is provided. Enumerates Aggregate.* anchors from
# the listed modeling units and verifies each appears in some module's
# "持有聚合" field of the plan.
if [[ -n "$UPSTREAMS" ]]; then
  IFS=',' read -ra UP_LIST <<< "$UPSTREAMS"
  MISSING_AGG=""
  for upstream in "${UP_LIST[@]}"; do
    upstream=$(echo "$upstream" | tr -d ' ')
    [[ -z "$upstream" ]] && continue
    if [[ ! -f "$upstream" ]]; then
      echo "Error: --upstream file not found: $upstream" >&2
      exit 1
    fi
    # Validate the upstream path shape (reuse the scenario convention).
    base=$(basename "$upstream")
    scenario=$(basename "$(dirname "$upstream")")
    if [[ ! "$base" =~ ^${UNIT_NAME_RE}\.md$ ]] || [[ ! "$scenario" =~ ^(${SCENARIO_ALT})$ ]]; then
      echo "Error: --upstream must be a modeling unit path ending with <scenario>/<name>.md (got: $upstream)" >&2
      exit 1
    fi
    # Extract Aggregate.* anchors declared in this upstream.
    while IFS= read -r anchor; do
      [[ -z "$anchor" ]] && continue
      # anchor is like "Aggregate.Order" — construct the expected short ref
      # using this upstream's scenario/name identity. Plans may use either
      # full path or short path; match by ending "/scenario/name.md#anchor".
      expected_suffix="${scenario}/${base}#${anchor}"
      # Check every held-aggregate ref in AGG_FILE ends with this suffix.
      if ! awk -F'\t' -v suf="$expected_suffix" '$2 ~ suf "$" { found=1; exit } END { exit !found }' "$AGG_FILE"; then
        MISSING_AGG+="  - ${scenario}/${base}#${anchor} (declared in upstream but not held by any plan module)"$'\n'
      fi
    done < <(grep -oE '<!-- anchor: Aggregate\.[A-Za-z0-9._-]+ -->' "$upstream" 2>/dev/null | \
             sed -E 's/<!-- anchor: //; s/ -->$//' | sort -u)
  done
  if [[ -n "$MISSING_AGG" ]]; then
    echo "❌ Check 4 FAILED: upstream Aggregate(s) not held by any plan module (aggregate未落位)" >&2
    printf "%s" "$MISSING_AGG" >&2
    [[ $fail -eq 0 ]] && fail=5
  fi
fi

if [[ $fail -ne 0 ]]; then
  exit $fail
fi

echo "✅ check-plan-structure: all structural constraints satisfied"
exit 0
