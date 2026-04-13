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
# Usage:
#   check-upstream-coverage.sh \
#     --upstream <path/to/model.md>[,<path/to/epic-model.md>,...] \
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

# ── Self-test: regression suite exercising R3..R5 corner cases ───────────
if [[ "${SELF_TEST:-0}" -eq 1 ]]; then
  SELF_SCRIPT="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
  ST_DIR=$(mktemp -d)
  trap 'rm -rf "$ST_DIR"' EXIT
  cd "$ST_DIR"
  mkdir -p src tests
  cat > model.md <<'EOF_SELF'
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

  run_case() {
    local name="$1"; local expected="$2"; local matrix_content="$3"
    echo "$matrix_content" > matrix.md
    local actual
    bash "$SELF_SCRIPT" --upstream model.md --matrix matrix.md --repo-root "$ST_DIR" >/dev/null 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }

  fails=0
  run_case "cancel identifier (contains n)" 0 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "render/pagination identifier" 0 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:render | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:pagination | ✅ |" || ((fails++))
  run_case "complex symbol rejected" 4 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:get total() | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "HTML comment must not count (single-line)" 3 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- model.md#Invariant.Order.1 is covered elsewhere -->" || ((fails++))
  run_case "HTML comment with > inside" 3 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- note: a > b, also model.md#Invariant.Order.1 -->" || ((fails++))
  run_case "multi-line HTML comment" 3 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- multi
line containing model.md#Invariant.Order.1
still inside comment -->" || ((fails++))
  run_case "NOT APPLICABLE + rationale passes" 0 "| model.md#Entity.Order | — | — | — | ⚠️ NOT APPLICABLE + reason text |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "NOT APPLICABLE: colon rejected" 3 "| model.md#Entity.Order | — | — | — | ⚠️ NOT APPLICABLE: bad separator |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "conflicting statuses detected" 3 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| model.md#Entity.Order | — | — | — | something broken |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "table header doesn't crash" 0 "| upstream | Spec | Test | Impl | Status |
|----------|------|------|------|--------|
| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "invalid line number" 4 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:99999 | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "blank line doesn't crash" 0 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |

| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "prose line doesn't crash" 0 "# Coverage Matrix

这是一段散文，没有任何 ref。
Some English prose without refs either.

| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "nested <!-- fails closed" 5 "<!-- outer <!-- inner --> model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ | outer -->
| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |" || ((fails++))
  run_case "unclosed <!-- fails closed" 5 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- this comment never closes" || ((fails++))
  run_case "stray --> on its own line fails closed" 5 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
--> stray closer should fail closed
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "stray --> after valid close fails closed" 5 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
<!-- valid --> --> extra stray --
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "adjacent comments same line pass" 0 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ | <!-- a --><!-- b -->
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |" || ((fails++))
  run_case "fake ref in matrix must be caught by Check 1" 2 "| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
| model.md#Entity.FAKE | S | src/order.ts:1 | src/order.ts:render | ✅ |" || ((fails++))

  # ── Parenthesized upstream-ref in refs-glob files ─────────────
  # When prose wraps the ref with `(...)` or `（...）`, the trailing paren must
  # not leak into the anchor (would make Check 1 report a fake ref).
  run_case_with_ref() {
    local name="$1"; local expected="$2"; local ref_file_name="$3"; local ref_content="$4"
    cat > matrix.md <<EOF_MATRIX
| model.md#Entity.Order | S | src/order.ts:1 | src/order.ts:cancel | ✅ |
| model.md#Invariant.Order.1 | S | src/order.ts:1 | src/order.ts:validate | ✅ |
EOF_MATRIX
    mkdir -p "$(dirname "$ref_file_name")"
    echo "$ref_content" > "$ref_file_name"
    local actual
    bash "$SELF_SCRIPT" --upstream model.md --matrix matrix.md --refs-glob "$(dirname "$ref_file_name")/*" --repo-root "$ST_DIR" >/dev/null 2>&1
    actual=$?
    rm -f "$ref_file_name"
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS [$name] exit=$actual"
    else
      echo "FAIL [$name] expected=$expected actual=$actual"
      return 1
    fi
  }
  run_case_with_ref "ref with ascii paren trailing" 0 "docs/spec.md" "rule X (upstream-ref: model.md#Entity.Order)" || ((fails++))
  run_case_with_ref "ref with chinese paren trailing" 0 "docs/spec2.md" "规则 Y（upstream-ref: model.md#Entity.Order）" || ((fails++))
  run_case_with_ref "ref with comma trailing" 0 "docs/spec3.md" "See upstream-ref: model.md#Entity.Order, continuing" || ((fails++))

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

for upstream in "${UPSTREAM_LIST[@]}"; do
  upstream=$(echo "$upstream" | tr -d ' ')
  if [[ ! -f "$upstream" ]]; then
    echo "Error: upstream file not found: $upstream" >&2
    exit 1
  fi
  abs=$(abs_path "$upstream")
  UPSTREAM_ABS_PATHS+=("$abs")
  count=0
  while IFS= read -r anchor; do
    [[ -z "$anchor" ]] && continue
    echo -e "${abs}\t${anchor}" >> "$ANCHOR_INDEX"
    ((count++)) || true
  done < <(extract_anchors "$upstream")
  echo "Upstream: $upstream (abs: $abs, anchors: $count)"
done

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
        anchor="${ref#*#}"
        # Strip trailing punctuation commonly left when refs are embedded in prose/tables:
        # `)` `）` `]` `,` `.` `;` `:` `。` `，` `；` `：` (Chinese punctuation included).
        anchor=$(echo "$anchor" | sed -E 's/[)\)\],;:。，；：]+$//')
        # Resolve doc path relative to the referencing file's directory,
        # then compare against any of the registered upstream absolute paths.
        src_dir=$(dirname "$file")
        if [[ "$doc" = /* ]]; then
          doc_abs="$doc"
        else
          doc_abs=$(cd "$src_dir" 2>/dev/null && cd "$(dirname "$doc")" 2>/dev/null && echo "$(pwd)/$(basename "$doc")" || echo "")
        fi
        # Fallback: if resolution failed, try basename match against any registered upstream
        if [[ -z "$doc_abs" || ! -f "$doc_abs" ]]; then
          doc_base=$(basename "$doc")
          for up in "${UPSTREAM_ABS_PATHS[@]}"; do
            if [[ "$(basename "$up")" == "$doc_base" ]]; then
              # Only fall back if exactly one upstream has this basename
              matches=0
              for u2 in "${UPSTREAM_ABS_PATHS[@]}"; do
                [[ "$(basename "$u2")" == "$doc_base" ]] && ((matches++)) || true
              done
              if [[ $matches -eq 1 ]]; then
                doc_abs="$up"
              fi
              break
            fi
          done
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
# matrix rows (e.g. `model.md#FAKE | ✅ |`) would slip through as "extra rows"
# that Check 2 ignores.
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
matrix_dir=$(dirname "$MATRIX")
matrix_lineno=0
while IFS= read -r row; do
  matrix_lineno=$((matrix_lineno + 1))
  [[ -z "$row" ]] && continue
  { echo "$row" | grep -oE '[^ |`<>]+\.md#[^ |`<>]+' 2>/dev/null || true; } | while read -r ref; do
    [[ "$ref" == *"#"* ]] || continue
    doc="${ref%%#*}"
    anchor="${ref#*#}"
    # Strip trailing punctuation that commonly appears when refs are embedded
    # in prose/tables: `)` `）` `,` `.` `;` `:` (Chinese punctuation included).
    anchor=$(echo "$anchor" | sed -E 's/[)\)\],;:。，；：]+$//')
    if [[ "$doc" = /* ]]; then
      doc_abs="$doc"
    else
      doc_abs=$(cd "$matrix_dir" 2>/dev/null && cd "$(dirname "$doc")" 2>/dev/null && echo "$(pwd)/$(basename "$doc")" || echo "")
    fi
    echo -e "${MATRIX}:${matrix_lineno}\t${doc_abs}\t${anchor}" >> "$REFS_FILE"
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
  # Empty doc = couldn't resolve — treat as fake
  if [[ -z "$doc" ]]; then
    echo "  - $src → (unresolvable doc path)#${anchor}" >> "$FAKE_LOG"
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
# For each line in matrix containing `<path>#<anchor>`, resolve <path> to
# absolute (relative to the matrix directory), then record (abs_doc, anchor) → status.
MATRIX_MAP="$TMP_DIR/matrix-map.tsv"   # columns: abs_doc TAB anchor TAB status (ok|invalid|unknown)
: > "$MATRIX_MAP"

# MATRIX_STRIPPED was already produced during the pre-Check-1 matrix ref scan.
# Re-use it here to build MATRIX_MAP with status information.
while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  row_stripped="$row"
  { echo "$row_stripped" | grep -oE '[^ |`<>]+\.md#[^ |`<>]+' 2>/dev/null || true; } | while read -r ref; do
    [[ "$ref" == *"#"* ]] || continue
    doc="${ref%%#*}"
    anchor="${ref#*#}"
    anchor=$(echo "$anchor" | sed -E 's/[)\)\],;:。，；：]+$//')
    if [[ "$doc" = /* ]]; then
      doc_abs="$doc"
    else
      doc_abs=$(cd "$matrix_dir" 2>/dev/null && cd "$(dirname "$doc")" 2>/dev/null && echo "$(pwd)/$(basename "$doc")" || echo "")
    fi
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

# Extract from the stripped matrix so commented-out locations aren't validated
# Strip trailing whitespace from each suffix
grep -oE "$LOC_PATTERN" "$MATRIX_STRIPPED" 2>/dev/null | \
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
