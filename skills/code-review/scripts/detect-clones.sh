#!/usr/bin/env bash
# detect-clones.sh — jscpd wrapper for code-review skill
# Runs clone detection and outputs structured JSON report
#
# Usage:
#   detect-clones.sh [options]
#
# Options:
#   --scope=diff      Scan full project but highlight clones involving changed files
#   --scope=full      Scan entire project (default)
#   --base=<branch>   Base branch for diff mode (default: main)
#   --min-lines=<n>   Minimum clone block size in lines (default: 5)
#   --min-tokens=<n>  Minimum clone block size in tokens (default: 50)
#   --path=<dir>      Target directory (default: git root)
#   -h, --help        Show this help
#
# Output:
#   JSON report written to <project>/.code-review/clones-report.json
#   Console summary printed to stdout

set -eo pipefail

# ── Defaults ──────────────────────────────────────────────
SCOPE="full"
BASE_BRANCH="main"
MIN_LINES=5
MIN_TOKENS=50
TARGET_PATH=""

# ── Parse arguments ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope=*)      SCOPE="${1#*=}"; shift ;;
    --base=*)       BASE_BRANCH="${1#*=}"; shift ;;
    --min-lines=*)  MIN_LINES="${1#*=}"; shift ;;
    --min-tokens=*) MIN_TOKENS="${1#*=}"; shift ;;
    --path=*)       TARGET_PATH="${1#*=}"; shift ;;
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

# ── Resolve project root ─────────────────────────────────
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository" >&2
  exit 1
}

if [[ -z "$TARGET_PATH" ]]; then
  TARGET_PATH="$GIT_ROOT"
fi

REPORT_DIR="$GIT_ROOT/.code-review"
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/clones-report.json"

# ── Check jscpd availability ─────────────────────────────
JSCPD_CMD=""
if command -v jscpd &>/dev/null; then
  JSCPD_CMD="jscpd"
elif command -v npx &>/dev/null; then
  JSCPD_CMD="npx jscpd"
else
  echo "Error: jscpd not found. Install with: npm install -g jscpd" >&2
  exit 1
fi

# ── Collect changed files for diff mode ───────────────────
CHANGED_FILES=""
if [[ "$SCOPE" == "diff" ]]; then
  CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH"...HEAD -- "$TARGET_PATH" 2>/dev/null || \
                  git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" HEAD -- "$TARGET_PATH")

  if [[ -z "$CHANGED_FILES" ]]; then
    echo '{"statistics":{"total":{"sources":0,"clones":0,"duplicatedLines":0,"percentage":0}},"duplicates":[]}' > "$REPORT_FILE"
    echo "No changed files found between $BASE_BRANCH and HEAD"
    exit 0
  fi

  echo "Diff mode: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ') changed files (vs $BASE_BRANCH)" >&2
  echo "Scanning full project to detect cross-file clones involving changed files..." >&2
else
  echo "Scanning full project: $TARGET_PATH" >&2
fi

# ── Build jscpd ignore pattern ────────────────────────────
IGNORE_PATTERN="**/node_modules/**,**/.git/**,**/dist/**,**/build/**,**/.code-review/**,**/.agent-loop/**,**/coverage/**,**/*.min.*,**/vendor/**,**/*.lock,**/package-lock.json,**/pnpm-lock.yaml"

# ── Run jscpd ────────────────────────────────────────────
# Always scan full project (even in diff mode) to catch cross-file clones.
# threshold=100 means "collect all clones, never fail on duplication level"
echo "Running jscpd (min-lines=$MIN_LINES, min-tokens=$MIN_TOKENS)..." >&2

$JSCPD_CMD \
  --min-lines "$MIN_LINES" \
  --min-tokens "$MIN_TOKENS" \
  --threshold 100 \
  --reporters json \
  --output "$REPORT_DIR" \
  --ignore "$IGNORE_PATTERN" \
  --blame \
  "$TARGET_PATH" 2>&1 | tee "$REPORT_DIR/jscpd-stdout.log" >&2

# ── Post-process report ──────────────────────────────────
JSCPD_RAW="$REPORT_DIR/jscpd-report.json"

if [[ ! -f "$JSCPD_RAW" ]]; then
  echo '{"statistics":{"total":{"sources":0,"clones":0,"duplicatedLines":0,"percentage":0}},"duplicates":[]}' > "$REPORT_FILE"
  echo "Warning: jscpd produced no report file" >&2
  exit 0
fi

cp "$JSCPD_RAW" "$REPORT_FILE"

# ── In diff mode, filter to clones involving changed files ─
if [[ "$SCOPE" == "diff" && -n "$CHANGED_FILES" ]]; then
  # Build a node script that filters duplicates to those touching changed files
  CHANGED_JSON=$(echo "$CHANGED_FILES" | node -e "
    const lines = require('fs').readFileSync('/dev/stdin','utf8').trim().split('\n');
    console.log(JSON.stringify(lines));
  ")

  node -e "
    const r = require('$REPORT_FILE');
    const changed = $CHANGED_JSON;
    const dupes = r.duplicates || [];
    const filtered = dupes.filter(d => {
      const fa = (d.firstFile && d.firstFile.name) || '';
      const sa = (d.secondFile && d.secondFile.name) || '';
      return changed.some(f => fa.includes(f) || sa.includes(f));
    });
    r.duplicates = filtered;
    r._scope = 'diff';
    r._changedFiles = changed;
    r._totalBeforeFilter = dupes.length;
    require('fs').writeFileSync('$REPORT_FILE', JSON.stringify(r, null, 2));
  "
  echo "Filtered: $(node -e "console.log(require('$REPORT_FILE').duplicates.length)") clones involve changed files (out of $(node -e "console.log(require('$REPORT_FILE')._totalBeforeFilter)") total)" >&2
fi

# ── Output summary ────────────────────────────────────────
if command -v node &>/dev/null; then
  node -e "
    const r = require('$REPORT_FILE');
    const s = r.statistics || {};
    const total = s.total || {};
    const clones = r.duplicates || [];
    console.log('');
    console.log('=== Clone Detection Report ===');
    console.log('Scope:            $SCOPE');
    console.log('Files scanned:    ' + (total.sources || 'N/A'));
    console.log('Total clones:     ' + clones.length);
    console.log('Duplicated lines: ' + (total.duplicatedLines || 'N/A'));
    console.log('Duplication %:    ' + (total.percentage || 'N/A') + '%');
    console.log('Report:           $REPORT_FILE');
    console.log('');
    if (clones.length > 0) {
      console.log('Top clones (by size):');
      clones
        .sort((a, b) => (b.lines || 0) - (a.lines || 0))
        .slice(0, 10)
        .forEach((c, i) => {
          const fa = c.firstFile || {};
          const sa = c.secondFile || {};
          console.log('  ' + (i+1) + '. [' + (c.lines || '?') + ' lines] '
            + (fa.name || 'unknown') + ':' + (fa.startLoc?.line || '?')
            + ' <-> '
            + (sa.name || 'unknown') + ':' + (sa.startLoc?.line || '?'));
        });
    }
  " 2>/dev/null || cat "$REPORT_FILE"
else
  cat "$REPORT_FILE"
fi

echo ""
echo "Full report: $REPORT_FILE"
