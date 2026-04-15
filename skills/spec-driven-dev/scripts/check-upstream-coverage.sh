#!/usr/bin/env bash
# check-upstream-coverage.sh
# Mechanical validation of upstream-ref fields in spec-driven-dev artifacts.
#
# Checks (all are HARD FAILS — any failure → non-zero exit):
#   1. Every upstream-ref in scenarios/tests/impl/plan/spec/matrix points to
#      a real anchor (<!-- anchor: X --> comment) in the upstream document.
#      Supports multi-ref (comma-separated) and multi-doc references.
#   2. Every anchor in the upstream document appears in the Coverage Matrix
#      with status `✅` or `⚠️ NOT APPLICABLE` + non-empty rationale.
#   3. Every Spec/Test/Impl location (file:line or file:symbol) in the matrix
#      points to a real file AND a valid line number (or existing symbol).
#
# Path convention (modeling-first v0.3+):
#   Upstream documents live at <path>/<scenario>/<name>.md where scenario
#   is one of: domain, ui, components, process, state-machine (fixed 5).
#   Refs may use relative or absolute paths — resolution is by the last two
#   path segments (<scenario>/<name>.md), which uniquely identify a
#   modeling unit. basename 'model.md' or 'epic-model.md' is NO LONGER
#   accepted — the script rejects them at load time.
#
# Usage:
#   check-upstream-coverage.sh \
#     --upstream <path/to/scenario/name.md>[,<another>,...] \
#     --matrix <path/to/coverage-matrix.md> \
#     [--refs-glob '<glob>'] \
#     [--repo-root <path>]
#
#   check-upstream-coverage.sh --self-test
#     Run the built-in regression suite (no arguments required).
#
# Exit codes:
#   0 — all checks pass
#   1 — usage error
#   2 — Check 1 failed (fake upstream references)
#   3 — Check 2 failed (uncovered anchors OR invalid matrix status)
#   4 — Check 3 failed (fake Spec/Test/Impl locations)
#   5 — Matrix preprocessing failed (malformed HTML comment structure:
#       nested <!--, unclosed <!--, or stray --> without matching <!--)

set -eo pipefail

UPSTREAMS=""
MATRIX=""
REFS_GLOB=""
REPO_ROOT=""

# Fixed set of scenarios recognized by modeling-first v0.3+. Paths ending
# with /<scenario>/<name>.md where scenario is in this set are treated as
# modeling units. Any other basename/parent combination is rejected.
SCENARIO_ALT='domain|ui|components|process|state-machine'
# A single unit name segment: kebab-case (lowercase + digits + hyphens,
# must start with a letter or digit).
UNIT_NAME_RE='[a-z0-9][a-z0-9-]*'
# A complete unit path suffix, for anchoring refs and paths.
UNIT_SUFFIX_RE="(${SCENARIO_ALT})/${UNIT_NAME_RE}\\.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream=*)   UPSTREAMS="${1#*=}"; shift ;;
    --upstream)     UPSTREAMS="$2"; shift 2 ;;
    --matrix=*)     MATRIX="${1#*=}"; shift ;;
    --matrix)       MATRIX="$2"; shift 2 ;;
    --refs-glob=*)  REFS_GLOB="${1#*=}"; shift ;;
    --refs-glob)    REFS_GLOB="$2"; shift 2 ;;
    --repo-root=*)  REPO_ROOT="${1#*=}"; shift ;;
    --repo-root)    REPO_ROOT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^$/{s/^# //;s/^#//;p;}' "$0"
      exit 0
      ;;
    --self-test)
      SELF_TEST=1; shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Compute the unit identity (last two path segments) for a given path.
# Returns "scenario/name.md" on success; empty string if the path does
# not conform to the modeling-first convention.
unit_id() {
  local path="$1"
  local base
  base=$(basename "$path")
  local scenario
  scenario=$(basename "$(dirname "$path")")
  if [[ "$base" =~ ^${UNIT_NAME_RE}\.md$ ]] && \
     [[ "$scenario" =~ ^(${SCENARIO_ALT})$ ]]; then
    echo "${scenario}/${base}"
  else
    echo ""
  fi
}

# ── Self-test: regression suite exercising R3..R5 corner cases ───────────
if [[ "${SELF_TEST:-0}" -eq 1 ]]; then
  SELF_SCRIPT="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
  ST_DIR=$(mktemp -d)
  trap 'rm -rf "$ST_DIR"' EXIT
  cd "$ST_DIR"
  mkdir -p src tests docs/models/domain docs/models/ui docs/models/components docs/models/process docs/models/state-machine
  cat > docs/models/domain/orders.md <<'EOF_SELF'
<!-- anchor: Entity.Order -->
- Order
<!-- anchor: Invariant.Order.1 -->
- total >= 0
EOF_SELF
  cat > src/order.ts <<'EOF_SELF'
export function cancel() {}
export function validate() {}
export function render() {}
export function pagination() {}
EOF_SELF

  UPSTREAM_PRIMARY="docs/models/domain/orders.md"

  run_case() {
    local name="$1"; local expected="$2"; local matrix_content="$3"
    echo "$matrix_content" > matrix.md
    local actual
    bash "$SELF_SCRIPT" --upstream "$UPSTREAM_PRIMARY" --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }

  fails=0
  run_case "cancel identifier (contains n)" 0 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "render/pagination identifier" 0 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:render | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:pagination | ✅ |" || ((fails++))
  run_case "full path ref works (docs/models/...)" 0 "| docs/models/domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| docs/models/domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "complex symbol rejected" 4 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:get total() | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "HTML comment must not count (single-line)" 3 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- domain/orders.md#Invariant.Order.1 is covered elsewhere -->" || ((fails++))
  run_case "HTML comment with > inside" 3 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- note: a > b, also domain/orders.md#Invariant.Order.1 -->" || ((fails++))
  run_case "multi-line HTML comment" 3 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- multi
line containing domain/orders.md#Invariant.Order.1
still inside comment -->" || ((fails++))
  run_case "NOT APPLICABLE + rationale passes" 0 "| domain/orders.md#Entity.Order | — | — | — | ⚠️ NOT APPLICABLE + reason text |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "NOT APPLICABLE: colon rejected" 3 "| domain/orders.md#Entity.Order | — | — | — | ⚠️ NOT APPLICABLE: bad separator |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "conflicting statuses detected" 3 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Entity.Order | — | — | — | something broken |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "table header doesn't crash" 0 "| upstream | Spec | Test | Impl | Status |
|----------|------|------|------|--------|
| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "invalid line number" 4 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:99999 | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "blank line doesn't crash" 0 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |

| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "prose line doesn't crash" 0 "# Coverage Matrix

这是一段散文，没有任何 ref。
Some English prose without refs either.

| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "nested <!-- fails closed" 5 "<!-- outer <!-- inner --> domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ | outer -->
| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "unclosed <!-- fails closed" 5 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- this comment never closes" || ((fails++))
  run_case "stray --> on its own line fails closed" 5 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
--> stray closer should fail closed
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "stray --> after valid close fails closed" 5 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- valid --> --> extra stray --
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "adjacent comments same line pass" 0 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ | <!-- a --><!-- b -->
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "fake ref in matrix must be caught by Check 1" 2 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| domain/orders.md#Entity.FAKE | S | src/order.ts:1 | src/order.ts:render | ✅ |" || ((fails++))
  # Matrix row referencing a path that is NOT a modeling unit (wrong scenario
  # parent or legacy basename) MUST be caught by Check 1 (exit 2).
  run_case "matrix row with legacy model.md basename caught by Check 1" 2 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:render | ✅ |" || ((fails++))
  run_case "matrix row with unknown scenario caught by Check 1" 2 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| unknown/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:render | ✅ |" || ((fails++))
  # Matrix row with non-namespace anchor MUST be caught by Check 1 (exit 2).
  run_case "matrix row with non-namespace anchor caught by Check 1" 2 "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| domain/orders.md#OrderThing | S | src/order.ts:1 | src/order.ts:render | ✅ |" || ((fails++))

  # ── Parenthesized upstream-ref in refs-glob files ─────────────
  # When prose wraps the ref with `(...)` or `（...）`, the trailing paren must
  # not leak into the anchor (would make Check 1 report a fake ref).
  run_case_with_ref() {
    local name="$1"; local expected="$2"; local ref_file_name="$3"; local ref_content="$4"
    cat > matrix.md <<EOF_MATRIX
| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
EOF_MATRIX
    mkdir -p "$(dirname "$ref_file_name")"
    echo "$ref_content" > "$ref_file_name"
    local actual
    bash "$SELF_SCRIPT" --upstream "$UPSTREAM_PRIMARY" --matrix matrix.md --refs-glob "$(dirname "$ref_file_name")/*" --repo-root "$ST_DIR" >/dev/null 2>&1
    actual=$?
    rm -f "$ref_file_name"
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }
  run_case_with_ref "ref with ascii paren trailing" 0 "spec/orders.md" "rule X (upstream-ref: domain/orders.md#Entity.Order)" || ((fails++))
  run_case_with_ref "ref with chinese paren trailing" 0 "spec/orders2.md" "规则 Y（upstream-ref: domain/orders.md#Entity.Order）" || ((fails++))
  run_case_with_ref "ref with comma trailing" 0 "spec/orders3.md" "See upstream-ref: domain/orders.md#Entity.Order, continuing" || ((fails++))
  run_case_with_ref "ref with full path works" 0 "spec/orders-full.md" "upstream-ref: docs/models/domain/orders.md#Entity.Order" || ((fails++))
  # legacy basename in refs rejected
  run_case_with_ref "ref to model.md (legacy) rejected" 2 "spec/orders4.md" "upstream-ref: model.md#Entity.Order" || ((fails++))
  # unknown scenario rejected
  run_case_with_ref "ref with unknown scenario rejected" 2 "spec/orders5.md" "upstream-ref: other/orders.md#Entity.Order" || ((fails++))
  # anchor without namespace prefix rejected
  run_case_with_ref "ref with non-namespace anchor rejected" 2 "spec/orders6.md" "upstream-ref: domain/orders.md#OrderThing" || ((fails++))
  # --upstream pointing at non-modeling-first path rejected at load time
  echo "- x" > other.md
  cat > matrix.md <<'EOF_MATRIX'
| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
EOF_MATRIX
  actual=$(bash "$SELF_SCRIPT" --upstream other.md --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "1" ]]; then
    echo "PASS [--upstream rejects non-modeling-first path] exit=$actual"
  else
    echo "FAIL [--upstream rejects non-modeling-first path] expected=1 actual=$actual"
    ((fails++))
  fi
  rm -f other.md

  # --upstream pointing at a legacy basename rejected at load time
  mkdir -p legacy/domain
  echo "<!-- anchor: Entity.X -->" > legacy/model.md
  cat > matrix.md <<'EOF_MATRIX'
| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
EOF_MATRIX
  actual=$(bash "$SELF_SCRIPT" --upstream legacy/model.md --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "1" ]]; then
    echo "PASS [--upstream rejects legacy model.md basename] exit=$actual"
  else
    echo "FAIL [--upstream rejects legacy model.md basename] expected=1 actual=$actual"
    ((fails++))
  fi
  rm -rf legacy

  # --upstream rejects two files sharing the same unit identity (would silently misroute)
  mkdir -p a/domain b/domain
  cat > a/domain/shared.md <<'EOF_A'
<!-- anchor: Entity.A -->
- A
EOF_A
  cat > b/domain/shared.md <<'EOF_A'
<!-- anchor: Entity.B -->
- B
EOF_A
  cat > matrix.md <<'EOF_MATRIX'
| domain/shared.md#Entity.A | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
EOF_MATRIX
  actual=$(bash "$SELF_SCRIPT" --upstream a/domain/shared.md,b/domain/shared.md --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "1" ]]; then
    echo "PASS [--upstream rejects duplicate unit identity] exit=$actual"
  else
    echo "FAIL [--upstream rejects duplicate unit identity] expected=1 actual=$actual"
    ((fails++))
  fi
  rm -rf a b

  # ── Scenario-specific namespace coverage ─────
  # Ensures every scenario + namespace combination is exercised end-to-end.
  cat > docs/models/domain/billing.md <<'EOF_DOM'
<!-- anchor: Aggregate.Order -->
- Order aggregate
<!-- anchor: Entity.Order -->
- Order
<!-- anchor: Rel.Order-User -->
- Order references User
<!-- anchor: Invariant.Order.1 -->
- total >= 0
<!-- anchor: Invariant.Order.cross.1 -->
- cross-module invariant enforced here
<!-- anchor: Derivation.Order.total -->
- total = sum(items.price)
<!-- anchor: StateMachine.Order -->
- Order lifecycle
<!-- anchor: Process.Checkout -->
- Checkout flow
EOF_DOM
  cat > docs/models/ui/dashboard.md <<'EOF_UI'
<!-- anchor: Entity.OrderSummary -->
- view model
<!-- anchor: Component.OrderCard -->
- UI component
<!-- anchor: StateMachine.OrderCard -->
- card state machine
<!-- anchor: Invariant.OrderCard.1 -->
- card invariant
EOF_UI
  cat > docs/models/components/modal.md <<'EOF_COMP'
<!-- anchor: Component.Modal -->
- Modal
<!-- anchor: StateMachine.Modal -->
- open/closed
<!-- anchor: Invariant.Modal.1 -->
- modal invariant
EOF_COMP
  cat > docs/models/process/refund.md <<'EOF_PROC'
<!-- anchor: Process.Refund -->
- refund flow
<!-- anchor: Rel.Refund-Order -->
- refund touches order
<!-- anchor: Invariant.Process.1 -->
- idempotent
<!-- anchor: Invariant.Process.cross.1 -->
- cross-module concern
EOF_PROC
  cat > docs/models/state-machine/upload.md <<'EOF_SM'
<!-- anchor: StateMachine.Upload -->
- upload lifecycle
<!-- anchor: Invariant.Upload.1 -->
- no double upload
EOF_SM

  run_multi_case() {
    local name="$1"; local expected="$2"; local upstream="$3"; local matrix_content="$4"
    echo "$matrix_content" > matrix.md
    local actual
    bash "$SELF_SCRIPT" --upstream "$upstream" --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }
  run_multi_case "domain scenario: Aggregate / Entity / Rel / Invariant / Invariant.cross / Derivation / StateMachine / Process" 0 \
    "docs/models/domain/billing.md" \
    "| domain/billing.md#Aggregate.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/billing.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/billing.md#Rel.Order-User | S | src/order.ts:1 | src/order.ts:render | ✅ |
| domain/billing.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| domain/billing.md#Invariant.Order.cross.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| domain/billing.md#Derivation.Order.total | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| domain/billing.md#StateMachine.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/billing.md#Process.Checkout | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_multi_case "ui scenario: Entity / Component / StateMachine / Invariant" 0 \
    "docs/models/ui/dashboard.md" \
    "| ui/dashboard.md#Entity.OrderSummary | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| ui/dashboard.md#Component.OrderCard | S | src/order.ts:1 | src/order.ts:render | ✅ |
| ui/dashboard.md#StateMachine.OrderCard | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| ui/dashboard.md#Invariant.OrderCard.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_multi_case "components scenario: Component / StateMachine / Invariant" 0 \
    "docs/models/components/modal.md" \
    "| components/modal.md#Component.Modal | S | src/order.ts:1 | src/order.ts:render | ✅ |
| components/modal.md#StateMachine.Modal | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| components/modal.md#Invariant.Modal.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_multi_case "process scenario: Process / Rel / Invariant / Invariant.cross" 0 \
    "docs/models/process/refund.md" \
    "| process/refund.md#Process.Refund | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| process/refund.md#Rel.Refund-Order | S | src/order.ts:1 | src/order.ts:render | ✅ |
| process/refund.md#Invariant.Process.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| process/refund.md#Invariant.Process.cross.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_multi_case "state-machine scenario: StateMachine / Invariant" 0 \
    "docs/models/state-machine/upload.md" \
    "| state-machine/upload.md#StateMachine.Upload | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| state-machine/upload.md#Invariant.Upload.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))

  # Two upstreams with different scenarios but the same <name> are allowed
  # (identity is scenario/name, not name alone). Create a real same-name
  # companion so the test actually exercises cross-scenario name-sharing.
  cat > docs/models/ui/orders.md <<'EOF_UI_ORDERS'
<!-- anchor: Entity.OrdersList -->
- Orders list view model (distinct from domain Entity.Order)
<!-- anchor: Component.OrdersTable -->
- Orders table UI component
EOF_UI_ORDERS
  run_multi_case "two upstreams sharing name across scenarios allowed (domain/orders.md + ui/orders.md)" 0 \
    "docs/models/domain/orders.md,docs/models/ui/orders.md" \
    "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| ui/orders.md#Entity.OrdersList | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| ui/orders.md#Component.OrdersTable | S | src/order.ts:1 | src/order.ts:render | ✅ |" || ((fails++))

  # Distinct-name cross-scenario upstreams (domain/orders + ui/dashboard) also allowed.
  run_multi_case "two upstreams with distinct names across scenarios (domain/orders + ui/dashboard)" 0 \
    "docs/models/domain/orders.md,docs/models/ui/dashboard.md" \
    "| domain/orders.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/orders.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| ui/dashboard.md#Entity.OrderSummary | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| ui/dashboard.md#Component.OrderCard | S | src/order.ts:1 | src/order.ts:render | ✅ |
| ui/dashboard.md#StateMachine.OrderCard | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| ui/dashboard.md#Invariant.OrderCard.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))

  # ── Forward-compat: an ad-hoc PascalCase namespace the script doesn't know about
  # should pass Check 1 as long as the anchor actually exists in the upstream.
  # The modeling-first namespace set is authoritative; the script only shape-checks.
  cat > docs/models/domain/forward.md <<'EOF_FWD'
<!-- anchor: Entity.Thing -->
- Thing
<!-- anchor: Helper.Foo -->
- hypothetical future namespace registered by modeling-first
EOF_FWD
  run_multi_case "ad-hoc PascalCase namespace (forward-compat with modeling-first)" 0 \
    "docs/models/domain/forward.md" \
    "| domain/forward.md#Entity.Thing | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/forward.md#Helper.Foo | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))

  # anchor must NOT start with digit (strict regex requires namespace letter prefix)
  cat > docs/models/domain/digit.md <<'EOF_DIGIT'
<!-- anchor: Entity.Order -->
- Order
EOF_DIGIT
  cat > matrix.md <<'EOF_MATRIX'
| domain/digit.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| domain/digit.md#123.Order | S | src/order.ts:1 | src/order.ts:validate | ✅ |
EOF_MATRIX
  actual=$(bash "$SELF_SCRIPT" --upstream docs/models/domain/digit.md --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1; echo $?)
  # 123.Order has no namespace prefix → permissive catches as malformed → exit 2
  if [[ "$actual" == "2" ]]; then
    echo "PASS [digit-prefixed anchor rejected] exit=$actual"
  else
    echo "FAIL [digit-prefixed anchor rejected] expected=2 actual=$actual"
    ((fails++))
  fi

  echo ""
  if [[ $fails -eq 0 ]]; then
    echo "=== Self-test: ALL PASSED ==="
    exit 0
  else
    echo "=== Self-test: $fails FAILURE(S) ==="
    exit 1
  fi
fi

if [[ -z "$UPSTREAMS" ]] || [[ -z "$MATRIX" ]]; then
  echo "Error: --upstream and --matrix are required" >&2
  echo "Run with --help for usage" >&2
  exit 1
fi

if [[ ! -f "$MATRIX" ]]; then
  echo "Error: matrix file not found: $MATRIX" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

ANCHOR_INDEX="$TMP_DIR/anchors.tsv"      # columns: absolute-upstream-path TAB anchor
REFS_FILE="$TMP_DIR/refs.tsv"            # columns: source-file:line TAB absolute-doc-path TAB anchor
: > "$ANCHOR_INDEX"
: > "$REFS_FILE"

# ── Parse upstream list (comma-separated) and extract anchors ────
IFS=',' read -ra UPSTREAM_LIST <<< "$UPSTREAMS"

# Resolve upstream paths to absolute paths (identity is full path, not basename)
# to prevent ambiguity when multiple upstream files share the same basename.
abs_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    # python is more portable than realpath on macOS
    (cd "$(dirname "$path")" 2>/dev/null && echo "$(pwd)/$(basename "$path")") || echo "$path"
  fi
}

extract_anchors() {
  local file="$1"
  # Only accept explicit <!-- anchor: X --> markers — no heading fallback.
  # Filter out template placeholders (anchors containing < or > — these are
  # `<Name>` / `<Entity>` etc. from unfilled templates, not real anchors).
  { grep -oE '<!-- anchor: [^ ]+ -->' "$file" 2>/dev/null || true; } | \
    sed -E 's/<!-- anchor: //; s/ -->$//' | \
    grep -vE '[<>]' | \
    sort -u
}

declare -a UPSTREAM_ABS_PATHS=()
declare -a UPSTREAM_UNIT_IDS=()

for upstream in "${UPSTREAM_LIST[@]}"; do
  upstream=$(echo "$upstream" | tr -d ' ')
  if [[ ! -f "$upstream" ]]; then
    echo "Error: upstream file not found: $upstream" >&2
    exit 1
  fi
  uid=$(unit_id "$upstream")
  if [[ -z "$uid" ]]; then
    echo "Error: --upstream must be a modeling unit path ending with <scenario>/<name>.md" >&2
    echo "       scenario ∈ {domain, ui, components, process, state-machine}; <name> is kebab-case" >&2
    echo "       got: $upstream" >&2
    echo "       (modeling-first v0.3+ retired the 'model.md'/'epic-model.md' basename convention)" >&2
    exit 1
  fi
  abs=$(abs_path "$upstream")
  # Guard against same-unit-identity collision: refs resolve by
  # <scenario>/<name>.md suffix, so registering two upstreams with the
  # same unit identity would silently route every matching ref to the first.
  for prev in "${UPSTREAM_UNIT_IDS[@]}"; do
    if [[ "$prev" == "$uid" ]]; then
      echo "Error: two --upstream files share unit identity '$uid'" >&2
      echo "       refs resolve by <scenario>/<name>.md suffix only; run the script once per unit instead." >&2
      exit 1
    fi
  done
  UPSTREAM_ABS_PATHS+=("$abs")
  UPSTREAM_UNIT_IDS+=("$uid")
  count=0
  while IFS= read -r anchor; do
    [[ -z "$anchor" ]] && continue
    echo -e "${abs}\t${anchor}" >> "$ANCHOR_INDEX"
    ((count++)) || true
  done < <(extract_anchors "$upstream")
  echo "Upstream: $upstream (unit: $uid, anchors: $count)"
done

# Resolve an arbitrary <doc> path (as it appears in a ref) to the
# absolute path of a registered upstream, by matching the last two
# path segments (scenario/name.md). Returns empty string if the
# <doc> is not a valid modeling unit path or no upstream matches.
resolve_doc_to_abs() {
  local doc="$1"
  local uid
  uid=$(unit_id "$doc")
  [[ -z "$uid" ]] && { echo ""; return; }
  local i
  for i in "${!UPSTREAM_UNIT_IDS[@]}"; do
    if [[ "${UPSTREAM_UNIT_IDS[$i]}" == "$uid" ]]; then
      echo "${UPSTREAM_ABS_PATHS[$i]}"
      return
    fi
  done
  echo ""
}

# ── Collect all upstream-refs from source files ───────────
collect_refs() {
  local file="$1"
  [[ -z "$file" || ! -f "$file" ]] && return 0
  # Match lines containing `upstream-ref:` or `@upstream`
  # Support comma-separated multiple refs on one line.
  # Use `|| true` to handle the case where grep finds no matches (exit 1).
  { grep -nE '(upstream-ref:|@upstream)' "$file" 2>/dev/null || true; } | \
    while IFS=: read -r lineno rest; do
      # Strip leading "N:" then extract everything after the keyword
      # Keep only the portion after the keyword
      payload=$(echo "$rest" | sed -E 's/^.*(upstream-ref:|@upstream)[[:space:]]*//')
      # Allow trailing commentary after the last ref; stop at ) or | or backtick
      # But keep it simple: split by comma, each item is "doc#anchor"
      echo "$payload" | tr ',' '\n' | while read -r ref; do
        ref=$(echo "$ref" | sed -E 's/^[[:space:]]+//; s/[[:space:]].*$//')
        [[ -z "$ref" ]] && continue
        # Skip N/A markers
        if [[ "$ref" =~ ^N/A ]]; then
          continue
        fi
        # Must contain exactly one #
        if [[ "$ref" != *"#"* ]]; then
          continue
        fi
        doc="${ref%%#*}"
        anchor_raw="${ref#*#}"
        # Strict anchor regex: namespace.name from modeling-first anchor conventions.
        # The regex naturally terminates at any punctuation (`)`, `]`, `,`, `。` etc.),
        # so refs embedded in prose or tables lose trailing junk without explicit stripping.
        # Namespace regex: PascalCase prefix + "." + name. The set of valid
        # namespaces is authoritatively defined by modeling-first and enforced
        # semantically by prompts/upstream-review.md. The script only requires
        # (a) PascalCase-shaped prefix and (b) that the anchor actually exists
        # in the upstream document (Check 1). Adding a new modeling-first
        # namespace therefore does NOT require updating this script.
        if [[ "$anchor_raw" =~ ^[A-Z][A-Za-z0-9]*\.[A-Za-z0-9._-]+ ]]; then
          anchor="${BASH_REMATCH[0]}"
        else
          # Record as unresolvable → Check 1 will report it.
          echo -e "${file}:${lineno}\t__UNRESOLVED__:${doc}#${anchor_raw}\t__INVALID_ANCHOR__" >> "$REFS_FILE"
          continue
        fi
        # Doc must be a valid modeling unit path (<scenario>/<name>.md suffix).
        # Paths in refs may be relative or absolute; resolution is by unit identity.
        doc_abs=$(resolve_doc_to_abs "$doc")
        if [[ -z "$doc_abs" ]]; then
          # Either doc is not a modeling-unit path, or no registered upstream matches.
          echo -e "${file}:${lineno}\t__UNRESOLVED__:${doc}\t${anchor}" >> "$REFS_FILE"
          continue
        fi
        echo -e "${file}:${lineno}\t${doc_abs}\t${anchor}" >> "$REFS_FILE"
      done
    done
}

# Do NOT scan the matrix here — matrix entries use `<doc>#<anchor>` directly
# without `upstream-ref:` prefix; they're validated by Check 2 instead.
# Only scan files matched by --refs-glob (scenarios, tests, spec docs).

# Scan refs-glob if provided. Supports comma-separated list of globs.
# `**` = any depth (zero or more path segments), `*` = any characters except `/`.
# Implemented via find + regex filter (portable, works on bash 3/4).
glob_to_regex() {
  local glob="$1"
  local rx
  # Escape regex special chars except glob wildcards
  rx=$(echo "$glob" | sed -E 's|[.^$+(){}|]|\\&|g')
  # Order matters: handle `**/` first (zero or more path segments),
  # then `**` alone, then `*`.
  rx=$(echo "$rx" | sed -E '
    s|\*\*/|<DOUBLESTAR_SLASH>|g
    s|\*\*|<DOUBLESTAR>|g
    s|\*|[^/]*|g
    s|<DOUBLESTAR_SLASH>|(.*/)?|g
    s|<DOUBLESTAR>|.*|g
  ')
  echo "^${REPO_ROOT}/${rx}$"
}

if [[ -n "$REFS_GLOB" ]]; then
  IFS=',' read -ra GLOB_LIST <<< "$REFS_GLOB"
  for glob in "${GLOB_LIST[@]}"; do
    glob=$(echo "$glob" | tr -d ' ')
    [[ -z "$glob" ]] && continue
    regex=$(glob_to_regex "$glob")
    while IFS= read -r -d '' f; do
      [[ -f "$f" ]] || continue
      collect_refs "$f"
    done < <(find "$REPO_ROOT" -type f -print0 2>/dev/null | \
             { grep -zE "$regex" || true; })
  done
fi

# Also collect refs from the matrix itself — Check 1 must validate that every
# <doc>#<anchor> in the matrix points to a real anchor, otherwise fabricated
# matrix rows (e.g. `domain/orders.md#FAKE | ✅ |`) would slip through as
# "extra rows" that Check 2 ignores.
# We need MATRIX_STRIPPED here, but it hasn't been built yet — build it now
# (idempotent; later code will reuse the same file).
MATRIX_STRIPPED="$TMP_DIR/matrix-stripped.md"
AWK_STATUS=0
awk '
  BEGIN { in_comment = 0 }
  {
    line = $0
    out = ""
    while (1) {
      if (in_comment) {
        close_idx = index(line, "-->")
        open_idx  = index(line, "<!--")
        if (open_idx > 0 && (close_idx == 0 || open_idx < close_idx)) {
          print "ERROR: nested <!-- ... <!-- ... --> detected at matrix line " NR ". HTML comment nesting is not allowed." > "/dev/stderr"
          exit 2
        }
        if (close_idx == 0) { line = ""; break }
        in_comment = 0
        line = substr(line, close_idx + 3)
      } else {
        idx = index(line, "<!--")
        if (idx == 0) {
          if (index(line, "-->") > 0) {
            print "ERROR: stray --> without matching <!-- at matrix line " NR "." > "/dev/stderr"
            exit 2
          }
          out = out line; line = ""; break
        }
        pre = substr(line, 1, idx - 1)
        if (index(pre, "-->") > 0) {
          print "ERROR: stray --> without matching <!-- at matrix line " NR "." > "/dev/stderr"
          exit 2
        }
        out = out pre
        line = substr(line, idx + 4)
        in_comment = 1
      }
    }
    print out
  }
  END {
    if (in_comment) {
      print "ERROR: unclosed <!-- at end of matrix file." > "/dev/stderr"
      exit 2
    }
  }
' "$MATRIX" > "$MATRIX_STRIPPED" || AWK_STATUS=$?

if [[ "$AWK_STATUS" -ne 0 ]]; then
  echo "❌ Matrix preprocessing FAILED: malformed HTML comment structure (exit $AWK_STATUS)" >&2
  exit 5
fi

# Scan stripped matrix for refs and record them in REFS_FILE for Check 1.
# Strict pattern: <path-ending-with-scenario/name.md>#<namespace>.<name>
# The regex naturally stops at non-namespace characters (punctuation, pipes, etc.).
# Namespace regex: PascalCase prefix (see collect_refs comment). The modeling-first
# namespace set is authoritative; this script only shape-checks.
MATRIX_REF_RE="[A-Za-z0-9_./-]*(${SCENARIO_ALT})/${UNIT_NAME_RE}\\.md#[A-Z][A-Za-z0-9]*\\.[A-Za-z0-9._-]+"
matrix_lineno=0
while IFS= read -r row; do
  matrix_lineno=$((matrix_lineno + 1))
  [[ -z "$row" ]] && continue
  # First pass: strict regex — collect well-formed refs.
  { echo "$row" | grep -oE "$MATRIX_REF_RE" 2>/dev/null || true; } | while read -r ref; do
    [[ "$ref" == *"#"* ]] || continue
    doc="${ref%%#*}"
    anchor="${ref#*#}"
    doc_abs=$(resolve_doc_to_abs "$doc")
    echo -e "${MATRIX}:${matrix_lineno}\t${doc_abs}\t${anchor}" >> "$REFS_FILE"
  done
  # Second pass: permissive regex — catch malformed refs (wrong scenario,
  # legacy basename, or non-namespace anchor) that the strict regex would
  # silently skip. This preserves the documented invariant: every
  # <doc>#<anchor>-shaped token in the matrix is validated by Check 1
  # (exit 2), not left to Check 2.
  { echo "$row" | grep -oE '[A-Za-z0-9_./-]+\.md#[A-Za-z0-9_.-]+' 2>/dev/null || true; } | while read -r raw_ref; do
    # Skip if the strict regex would have matched (already recorded above).
    if echo "$raw_ref" | grep -qE "^${MATRIX_REF_RE}$"; then
      continue
    fi
    # Malformed ref → record as unresolvable so Check 1 reports it.
    echo -e "${MATRIX}:${matrix_lineno}\t__UNRESOLVED__:${raw_ref}\t__INVALID_MATRIX_REF__" >> "$REFS_FILE"
  done
done < "$MATRIX_STRIPPED"

REF_COUNT=$(wc -l < "$REFS_FILE" | tr -d ' ')
echo "Collected upstream-refs: $REF_COUNT"

# ── Check 1: every upstream-ref points to a real anchor ────
FAIL_1=0
FAKE_LOG="$TMP_DIR/fake.log"
: > "$FAKE_LOG"

while IFS=$'\t' read -r src doc anchor; do
  [[ -z "$anchor" ]] && continue
  # Unresolvable marker (non-modeling-unit path, invalid anchor format, or missing upstream)
  if [[ "$doc" == __UNRESOLVED__:* ]]; then
    orig="${doc#__UNRESOLVED__:}"
    echo "  - $src → ${orig} (doc path must end with <scenario>/<name>.md where scenario ∈ {domain,ui,components,process,state-machine}; anchor must be PascalCase.<name>, e.g. Entity.Order / Invariant.Order.3 — valid namespaces defined by modeling-first)" >> "$FAKE_LOG"
    FAIL_1=1
    continue
  fi
  # Empty doc = no upstream registered with this unit identity — treat as fake
  if [[ -z "$doc" ]]; then
    echo "  - $src → (no registered upstream matches this unit identity)#${anchor}" >> "$FAKE_LOG"
    FAIL_1=1
    continue
  fi
  # Match absolute path + anchor
  if ! awk -F'\t' -v d="$doc" -v a="$anchor" \
        '$1==d && $2==a { found=1; exit } END { exit !found }' "$ANCHOR_INDEX"; then
    echo "  - $src → ${doc}#${anchor}" >> "$FAKE_LOG"
    FAIL_1=1
  fi
done < "$REFS_FILE"

if [[ $FAIL_1 -eq 1 ]]; then
  echo ""
  echo "❌ Check 1 FAILED: fake upstream references found" >&2
  cat "$FAKE_LOG" >&2
  exit 2
fi
echo "✅ Check 1 passed: all upstream-refs point to real anchors"

# ── Check 2: matrix coverage of upstream anchors ──────────
# For each anchor in ANCHOR_INDEX, find the matrix row and verify status.
FAIL_2=0
MISSING_LOG="$TMP_DIR/missing.log"
: > "$MISSING_LOG"

# Extract matrix rows: a row is a markdown table row containing the anchor.
# Each row must contain either `✅` or `⚠️ NOT APPLICABLE + <non-empty rationale>`.
# Only `+` is accepted as the rationale separator (colon is NOT allowed to avoid
# ambiguity with doc:anchor references).

# First pass: build a map of matrix entries.
MATRIX_MAP="$TMP_DIR/matrix-map.tsv"   # columns: abs_doc TAB anchor TAB status (ok|invalid|unknown)
: > "$MATRIX_MAP"

# MATRIX_STRIPPED was already produced during the pre-Check-1 matrix ref scan.
# Re-use it here to build MATRIX_MAP with status information.
while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  row_stripped="$row"
  { echo "$row_stripped" | grep -oE "$MATRIX_REF_RE" 2>/dev/null || true; } | while read -r ref; do
    [[ "$ref" == *"#"* ]] || continue
    doc="${ref%%#*}"
    anchor="${ref#*#}"
    doc_abs=$(resolve_doc_to_abs "$doc")
    if echo "$row_stripped" | grep -qE '✅'; then
      status="ok"
    elif echo "$row_stripped" | grep -qE 'NOT APPLICABLE[[:space:]]*\+[[:space:]]*[^[:space:]|]'; then
      status="ok"
    else
      status="invalid"
    fi
    echo -e "${doc_abs}\t${anchor}\t${status}" >> "$MATRIX_MAP"
  done
done < "$MATRIX_STRIPPED"

# Second pass: every upstream anchor must have a matching (abs_doc, anchor) row,
# AND all matching rows for that (abs_doc, anchor) must agree on status.
# Conflicting statuses (one ok + one invalid for the same anchor) are a DoD failure.
while IFS=$'\t' read -r doc anchor; do
  [[ -z "$doc" || -z "$anchor" ]] && continue
  # Count matching rows and check status consistency via awk.
  read -r total ok_count invalid_count < <(awk -F'\t' -v d="$doc" -v a="$anchor" '
    $1==d && $2==a {
      total++
      if ($3=="ok") ok++
      else invalid++
    }
    END { print (total+0), (ok+0), (invalid+0) }
  ' "$MATRIX_MAP")

  if [[ "$total" -eq 0 ]]; then
    echo "  - MISSING in matrix: ${doc}#${anchor}" >> "$MISSING_LOG"
    FAIL_2=1
  elif [[ "$invalid_count" -gt 0 && "$ok_count" -gt 0 ]]; then
    echo "  - CONFLICTING STATUSES for ${doc}#${anchor}: $ok_count ok row(s) + $invalid_count invalid row(s); matrix rows for the same anchor must agree" >> "$MISSING_LOG"
    FAIL_2=1
  elif [[ "$invalid_count" -gt 0 ]]; then
    echo "  - INVALID STATUS for ${doc}#${anchor}: must be ✅ or '⚠️ NOT APPLICABLE + <rationale>' (colon is not accepted)" >> "$MISSING_LOG"
    FAIL_2=1
  fi
  # else: total > 0 && invalid_count == 0 && ok_count > 0 → pass
done < "$ANCHOR_INDEX"

if [[ $FAIL_2 -eq 1 ]]; then
  echo ""
  echo "❌ Check 2 FAILED: uncovered anchors or invalid matrix status" >&2
  cat "$MISSING_LOG" >&2
  exit 3
fi
echo "✅ Check 2 passed: all upstream anchors covered with valid status"

# ── Check 3: matrix Spec/Test/Impl locations resolve ───────
FAIL_3=0
INVALID_LOG="$TMP_DIR/invalid-locs.log"
: > "$INVALID_LOG"

# Matrix locations MUST use one of two forms:
#   1. `path/to/file.ext:<lineno>` — integer line number only
#   2. `path/to/file.ext:<identifier>` — single identifier matching /^[A-Za-z_][A-Za-z0-9_]*$/
# Complex symbols (containing spaces, parens, dots, etc.) MUST use the line-number form.
#
# Extraction strategy: find any path-like token with a recognized extension,
# then greedily capture the suffix up to the next markdown-table separator,
# space, backtick, or angle-bracket. This way `get total()` is captured
# intact and later rejected by the suffix-shape check (rather than being
# silently truncated to `get`).
FILE_EXT_RE='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|rb|php|kt|swift|c|cc|cpp|h|hpp|md|yaml|yml|json)'
# Allow suffix to span spaces and punctuation — only table separators (`|`),
# backticks, and angle brackets terminate it. grep -oE works line-by-line,
# so we don't need to explicitly exclude newline. This captures
# `get total()` intact so the suffix-shape check can reject it.
#
# IMPORTANT: do NOT include `\n` or `\\n` in the character class — grep ERE
# treats those as the literal letter `n`, which would truncate any symbol
# containing `n` (e.g. `cancel`, `validate`, `render`).
LOC_PATTERN="[a-zA-Z0-9_./-]+\\.${FILE_EXT_RE}(:[^|\`<>]*)?"

# Extract from the stripped matrix so commented-out locations aren't validated.
# First strip `#<anchor>` fragments so anchors like `Invariant.Order.cross.1`
# don't produce false-positive location matches (e.g. `Invariant.Order.c` where
# `.c` is a valid file extension). Anchor fragments are terminated by markdown
# table separators / whitespace / newlines.
MATRIX_NO_ANCHORS="$TMP_DIR/matrix-no-anchors.md"
sed -E 's/#[A-Za-z_][A-Za-z0-9._-]*//g' "$MATRIX_STRIPPED" > "$MATRIX_NO_ANCHORS"
# Strip trailing whitespace from each suffix
grep -oE "$LOC_PATTERN" "$MATRIX_NO_ANCHORS" 2>/dev/null | \
  sed -E 's/[[:space:]]+$//' | \
  sort -u > "$TMP_DIR/locs.txt" || true

while IFS= read -r loc; do
  [[ -z "$loc" ]] && continue
  if [[ "$loc" == *:* ]]; then
    path_part="${loc%:*}"
    suffix="${loc##*:}"
  else
    path_part="$loc"
    suffix=""
  fi

  # Skip modeling-unit paths — those are refs validated by Check 1/2, not
  # Spec/Test/Impl locations. A path like `domain/orders.md` should never
  # be validated as a file-location (it has no `:<lineno>` / `:<identifier>`
  # suffix in matrix-ref form; and even when embedded in a ref like
  # `domain/orders.md#Entity.Order` the `#anchor` is stripped before we
  # arrive here — we'd otherwise try to resolve `domain/orders.md` as a
  # sibling of `matrix.md` and fail).
  if [[ "$path_part" =~ (^|/)(${SCENARIO_ALT})/${UNIT_NAME_RE}\.md$ ]]; then
    continue
  fi

  # Resolve path
  resolved=""
  for candidate in "$REPO_ROOT/$path_part" "$(dirname "$MATRIX")/$path_part" "$path_part"; do
    if [[ -f "$candidate" ]]; then
      resolved="$candidate"
      break
    fi
  done
  if [[ -z "$resolved" ]]; then
    echo "  - MISSING FILE: $loc" >> "$INVALID_LOG"
    FAIL_3=1
    continue
  fi

  [[ -z "$suffix" ]] && continue

  if [[ "$suffix" =~ ^[0-9]+$ ]]; then
    # line number: must be 1..line_count (strict upper bound)
    line_count=$(wc -l < "$resolved" | tr -d ' ')
    if (( suffix < 1 || suffix > line_count )); then
      echo "  - INVALID LINE: $loc (file has $line_count lines)" >> "$INVALID_LOG"
      FAIL_3=1
    fi
  elif [[ "$suffix" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    # identifier symbol: whole-word match in file
    if ! grep -qE "\\b${suffix}\\b" "$resolved" 2>/dev/null; then
      echo "  - SYMBOL NOT FOUND: $loc" >> "$INVALID_LOG"
      FAIL_3=1
    fi
  else
    # Suffix isn't a valid line number or identifier — likely truncated complex symbol
    echo "  - INVALID SUFFIX: $loc (use 'file:<lineno>' or 'file:<identifier>'; complex symbols must use line numbers)" >> "$INVALID_LOG"
    FAIL_3=1
  fi
done < "$TMP_DIR/locs.txt"

if [[ $FAIL_3 -eq 1 ]]; then
  echo ""
  echo "❌ Check 3 FAILED: matrix references invalid locations" >&2
  cat "$INVALID_LOG" >&2
  exit 4
fi
echo "✅ Check 3 passed: all matrix locations resolve to real files + valid lines/symbols"

echo ""
echo "=== Upstream Coverage Validation: PASSED ==="
