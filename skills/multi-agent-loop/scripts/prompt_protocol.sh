#!/usr/bin/env bash

PROMPT_PROTOCOL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_PROTOCOL_TEMPLATE_FILE="$PROMPT_PROTOCOL_SCRIPT_DIR/../templates/agent-prompt.txt"
PROMPT_PROTOCOL_TEMPLATE_LOADED=0
PROMPT_PROTOCOL_SEVERITY_LEVELS=(Critical Major Minor Info)
PROMPT_PROTOCOL_SEVERITY_EXTRA_LINES=$(( ${#PROMPT_PROTOCOL_SEVERITY_LEVELS[@]} - 1 ))

prompt_protocol_trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

prompt_protocol_parse_placeholder_values() {
  local placeholder_line="$1"
  local -n out_values="$2"
  local raw_values inner raw_value

  inner="${placeholder_line#*<}"
  inner="${inner%>}"

  IFS='|' read -r -a raw_values <<< "$inner"
  out_values=()
  for raw_value in "${raw_values[@]}"; do
    out_values+=("$(prompt_protocol_trim "$raw_value")")
  done
}

prompt_protocol_value_allowed() {
  local candidate="$1"
  shift

  local allowed_value
  for allowed_value in "$@"; do
    if [[ "$candidate" == "$allowed_value" ]]; then
      return 0
    fi
  done

  return 1
}

prompt_protocol_load_template() {
  local line idx

  if [[ "$PROMPT_PROTOCOL_TEMPLATE_LOADED" -eq 1 ]]; then
    return 0
  fi

  if [[ ! -f "$PROMPT_PROTOCOL_TEMPLATE_FILE" ]]; then
    echo "prompt template not found: $PROMPT_PROTOCOL_TEMPLATE_FILE" >&2
    return 1
  fi

  mapfile -t PROMPT_PROTOCOL_TEMPLATE_LINES < "$PROMPT_PROTOCOL_TEMPLATE_FILE"

  PROMPT_PROTOCOL_TYPE_INDEX=-1
  PROMPT_PROTOCOL_ROLE_INDEX=-1
  PROMPT_PROTOCOL_INSTRUCTION_INDEX=-1
  PROMPT_PROTOCOL_SEVERITY_INDEX=-1
  PROMPT_PROTOCOL_TYPE_PLACEHOLDER=""
  PROMPT_PROTOCOL_ROLE_PLACEHOLDER=""

  for idx in "${!PROMPT_PROTOCOL_TEMPLATE_LINES[@]}"; do
    line="${PROMPT_PROTOCOL_TEMPLATE_LINES[$idx]}"

    if [[ "$line" == "- 类型：<"*">" ]]; then
      if [[ "$PROMPT_PROTOCOL_TYPE_INDEX" -ne -1 ]]; then
        echo "prompt template is invalid: duplicate type placeholder" >&2
        return 1
      fi
      PROMPT_PROTOCOL_TYPE_INDEX=$idx
      PROMPT_PROTOCOL_TYPE_PLACEHOLDER="$line"
      continue
    fi

    if [[ "$line" == "- 角色：<"*">" ]]; then
      if [[ "$PROMPT_PROTOCOL_ROLE_INDEX" -ne -1 ]]; then
        echo "prompt template is invalid: duplicate role placeholder" >&2
        return 1
      fi
      PROMPT_PROTOCOL_ROLE_INDEX=$idx
      PROMPT_PROTOCOL_ROLE_PLACEHOLDER="$line"
      continue
    fi

    if [[ "$line" == "<在此描述具体任务>" ]]; then
      if [[ "$PROMPT_PROTOCOL_INSTRUCTION_INDEX" -ne -1 ]]; then
        echo "prompt template is invalid: duplicate instruction placeholder" >&2
        return 1
      fi
      PROMPT_PROTOCOL_INSTRUCTION_INDEX=$idx
      continue
    fi

    if [[ "$line" == "<严重度定义块>" ]]; then
      if [[ "$PROMPT_PROTOCOL_SEVERITY_INDEX" -ne -1 ]]; then
        echo "prompt template is invalid: duplicate severity placeholder" >&2
        return 1
      fi
      PROMPT_PROTOCOL_SEVERITY_INDEX=$idx
    fi
  done

  if [[ "$PROMPT_PROTOCOL_TYPE_INDEX" -lt 0 || "$PROMPT_PROTOCOL_ROLE_INDEX" -lt 0 || "$PROMPT_PROTOCOL_INSTRUCTION_INDEX" -lt 0 ]]; then
    echo "prompt template is invalid: missing type, role, or instruction placeholder" >&2
    return 1
  fi

  if [[ "$PROMPT_PROTOCOL_SEVERITY_INDEX" -lt 0 ]]; then
    echo "prompt template is invalid: missing severity placeholder '<严重度定义块>'" >&2
    return 1
  fi

  if [[ "$PROMPT_PROTOCOL_SEVERITY_INDEX" -le "$PROMPT_PROTOCOL_INSTRUCTION_INDEX" ]]; then
    echo "prompt template is invalid: severity placeholder must come after instruction placeholder" >&2
    return 1
  fi

  prompt_protocol_parse_placeholder_values "$PROMPT_PROTOCOL_TYPE_PLACEHOLDER" PROMPT_PROTOCOL_ALLOWED_TYPES
  prompt_protocol_parse_placeholder_values "$PROMPT_PROTOCOL_ROLE_PLACEHOLDER" PROMPT_PROTOCOL_ALLOWED_ROLES
  PROMPT_PROTOCOL_TEMPLATE_LOADED=1
}

prompt_protocol_expected_line() {
  local template_index="$1"
  local prompt_type="$2"
  local prompt_role="$3"
  local line="${PROMPT_PROTOCOL_TEMPLATE_LINES[$template_index]}"

  if [[ "$template_index" -eq "$PROMPT_PROTOCOL_TYPE_INDEX" ]]; then
    line="- 类型：$prompt_type"
  elif [[ "$template_index" -eq "$PROMPT_PROTOCOL_ROLE_INDEX" ]]; then
    line="- 角色：$prompt_role"
  fi

  printf '%s' "$line"
}

prompt_protocol_extract_value() {
  local line="$1"
  local prefix="$2"

  if [[ "$line" != "$prefix"* ]]; then
    return 1
  fi

  printf '%s' "${line#$prefix}"
}

prompt_protocol_required_peer_output_line() {
  local prompt_file="$1"
  local prompt_dir

  prompt_dir="$(cd "$(dirname "$prompt_file")" && pwd)"
  printf '主 agent 输出路径：%s/agent-output.md' "$prompt_dir"
}

prompt_protocol_required_peer_output_file() {
  local prompt_file="$1"
  local prompt_dir

  prompt_dir="$(cd "$(dirname "$prompt_file")" && pwd)"
  printf '%s/agent-output.md' "$prompt_dir"
}

prompt_protocol_severity_prefix() {
  local level="$1"
  printf -- '- `[%s]`：' "$level"
}

# Replace inline-code spans with spaces so downstream checks (table-row
# detection, heuristic scans) can reason about the "exposed" text without
# being fooled by `|` or emphasis markers that live inside literal code.
# Honors CommonMark's rule that a span opened by N backticks must close with
# exactly N backticks (so `` ``X`` `` is one span, not two). Walks the string
# char-by-char; O(n) and immune to glob pitfalls.
prompt_protocol_strip_inline_code() {
  local s="$1"
  local len=${#s}
  local result=""
  local i=0 j k scan scan_end open_count close_count found_close
  while (( i < len )); do
    if [[ "${s:$i:1}" != '`' ]]; then
      result+="${s:$i:1}"
      i=$((i+1))
      continue
    fi
    # Count consecutive opening backticks
    j=$i
    while (( j < len )) && [[ "${s:$j:1}" == '`' ]]; do
      j=$((j+1))
    done
    open_count=$((j - i))
    # Search ahead for a run of exactly open_count backticks
    found_close=-1
    scan=$j
    while (( scan < len )); do
      if [[ "${s:$scan:1}" == '`' ]]; then
        scan_end=$scan
        while (( scan_end < len )) && [[ "${s:$scan_end:1}" == '`' ]]; do
          scan_end=$((scan_end+1))
        done
        close_count=$((scan_end - scan))
        if (( close_count == open_count )); then
          found_close=$scan
          break
        fi
        scan=$scan_end
      else
        scan=$((scan+1))
      fi
    done
    if (( found_close >= 0 )); then
      for (( k=i; k<found_close+open_count; k++ )); do
        result+=" "
      done
      i=$((found_close+open_count))
    else
      # No matching closer: per CommonMark these backticks are literal
      result+="${s:$i:$open_count}"
      i=$j
    fi
  done
  printf '%s' "$result"
}

# Iteratively strip common non-pipe markdown container prefixes:
#   - bullet list:        `- `, `* `, `+ `
#   - ordered list:       `1. `, `2) `, `42. `
#   - checkbox list item: `[ ] `, `[x] `, `[X] ` (after list marker has been peeled)
#   - blockquote:         `> `, `> > `, etc.
# Pipes are intentionally NOT stripped here so the caller can detect table rows
# even when they are nested under other containers.
prompt_protocol_strip_nonpipe_containers() {
  local line="$1"
  local before=""
  while [[ "$line" != "$before" ]]; do
    before="$line"
    if [[ "$line" =~ ^([-*+])[[:space:]]+(.*)$ ]]; then
      line="${BASH_REMATCH[2]}"
      continue
    fi
    # CommonMark allows blockquote marker `>` with or without trailing whitespace
    # (`>X` is still a blockquote), so don't require a space here.
    if [[ "$line" =~ ^\>[[:space:]]*(.*)$ ]]; then
      line="${BASH_REMATCH[1]}"
      continue
    fi
    if [[ "$line" =~ ^[0-9]+[\.\)][[:space:]]+(.*)$ ]]; then
      line="${BASH_REMATCH[1]}"
      continue
    fi
    if [[ "$line" =~ ^\[[xX[:space:]]\][[:space:]]+(.*)$ ]]; then
      line="${BASH_REMATCH[1]}"
      continue
    fi
  done
  printf '%s' "$line"
}

# Strip both non-pipe containers and table-cell pipes. Used on individual
# (non-table-row) lines and on individual table cells once they have been split.
prompt_protocol_strip_containers() {
  local line
  line="$(prompt_protocol_strip_nonpipe_containers "$1")"
  local before=""
  while [[ "$line" != "$before" ]]; do
    before="$line"
    if [[ "$line" =~ ^\|[[:space:]]*(.*)$ ]]; then
      line="${BASH_REMATCH[1]}"
      line="$(prompt_protocol_trim "$line")"
      line="${line%|}"
      line="$(prompt_protocol_trim "$line")"
      line="$(prompt_protocol_strip_nonpipe_containers "$line")"
      continue
    fi
  done
  printf '%s' "$line"
}

prompt_protocol_reject_symlink() {
  local file_path="$1"
  local file_label="$2"
  local logical_dir physical_dir

  logical_dir="$(cd "$(dirname "$file_path")" && pwd -L)"
  physical_dir="$(cd "$(dirname "$file_path")" && pwd -P)"

  if [[ "$logical_dir" != "$physical_dir" ]]; then
    echo "$file_label must stay under a non-symlink canonical directory: $file_path" >&2
    return 1
  fi

  if [[ -L "$file_path" ]]; then
    echo "$file_label must not be a symlink: $file_path" >&2
    return 1
  fi
}

prompt_protocol_validate_prompt_file() {
  local prompt_file="$1"
  local expected_role="$2"
  local actual_type_line actual_role_line actual_type actual_role
  local prompt_line_count template_line_count prefix_line_count suffix_line_count
  local template_idx prompt_idx instruction_start instruction_end has_instruction_text
  local expected_line required_peer_line required_peer_file
  local -a prompt_lines

  prompt_protocol_load_template || return 1

  if [[ ! -f "$prompt_file" ]]; then
    echo "prompt file not found: $prompt_file" >&2
    return 1
  fi
  if ! prompt_protocol_reject_symlink "$prompt_file" "prompt file"; then
    return 1
  fi

  mapfile -t prompt_lines < "$prompt_file"
  # Normalize CRLF: drop trailing \r so editors/tools that write Windows line
  # endings don't cause spurious "value not allowed" style failures.
  local _i
  for (( _i = 0; _i < ${#prompt_lines[@]}; _i++ )); do
    prompt_lines[$_i]="${prompt_lines[$_i]%$'\r'}"
  done
  prompt_line_count=${#prompt_lines[@]}
  template_line_count=${#PROMPT_PROTOCOL_TEMPLATE_LINES[@]}
  prefix_line_count=$PROMPT_PROTOCOL_INSTRUCTION_INDEX
  suffix_line_count=$((template_line_count - PROMPT_PROTOCOL_INSTRUCTION_INDEX - 1 + PROMPT_PROTOCOL_SEVERITY_EXTRA_LINES))

  if (( prompt_line_count < template_line_count + PROMPT_PROTOCOL_SEVERITY_EXTRA_LINES )); then
    echo "prompt file does not follow template: too few lines" >&2
    return 1
  fi

  actual_type_line="${prompt_lines[$PROMPT_PROTOCOL_TYPE_INDEX]}"
  if ! actual_type="$(prompt_protocol_extract_value "$actual_type_line" "- 类型：")"; then
    echo "prompt file does not follow template: invalid type line '$actual_type_line'" >&2
    return 1
  fi
  if ! prompt_protocol_value_allowed "$actual_type" "${PROMPT_PROTOCOL_ALLOWED_TYPES[@]}"; then
    echo "prompt file does not follow template: type '$actual_type' is not allowed by template" >&2
    return 1
  fi

  actual_role_line="${prompt_lines[$PROMPT_PROTOCOL_ROLE_INDEX]}"
  if ! actual_role="$(prompt_protocol_extract_value "$actual_role_line" "- 角色：")"; then
    echo "prompt file does not follow template: invalid role line '$actual_role_line'" >&2
    return 1
  fi
  if ! prompt_protocol_value_allowed "$actual_role" "${PROMPT_PROTOCOL_ALLOWED_ROLES[@]}"; then
    echo "prompt file does not follow template: role '$actual_role' is not allowed by template" >&2
    return 1
  fi
  if [[ "$actual_role" != "$expected_role" ]]; then
    echo "prompt file role does not match runner role: expected '$expected_role', got '$actual_role'" >&2
    return 1
  fi

  for ((template_idx = 0; template_idx < prefix_line_count; template_idx++)); do
    expected_line="$(prompt_protocol_expected_line "$template_idx" "$actual_type" "$actual_role")"
    if [[ "${prompt_lines[$template_idx]}" != "$expected_line" ]]; then
      echo "prompt file does not follow template at line $((template_idx + 1)): expected '$expected_line'" >&2
      return 1
    fi
  done

  prompt_idx=$((prompt_line_count - suffix_line_count))
  for ((template_idx = PROMPT_PROTOCOL_INSTRUCTION_INDEX + 1; template_idx < template_line_count; template_idx++)); do
    if [[ "$template_idx" -eq "$PROMPT_PROTOCOL_SEVERITY_INDEX" ]]; then
      local severity_level severity_prefix severity_line severity_body
      for severity_level in "${PROMPT_PROTOCOL_SEVERITY_LEVELS[@]}"; do
        severity_prefix="$(prompt_protocol_severity_prefix "$severity_level")"
        severity_line="${prompt_lines[$prompt_idx]}"
        if [[ "$severity_line" != "$severity_prefix"* ]]; then
          echo "prompt file does not follow template at line $((prompt_idx + 1)): expected severity line for '$severity_level' starting with '$severity_prefix'" >&2
          return 1
        fi
        severity_body="${severity_line:${#severity_prefix}}"
        severity_body="$(prompt_protocol_trim "$severity_body")"
        if [[ -z "$severity_body" ]]; then
          echo "prompt file does not follow template at line $((prompt_idx + 1)): severity line for '$severity_level' has empty body" >&2
          return 1
        fi
        prompt_idx=$((prompt_idx + 1))
      done
      continue
    fi
    expected_line="${PROMPT_PROTOCOL_TEMPLATE_LINES[$template_idx]}"
    if [[ "${prompt_lines[$prompt_idx]}" != "$expected_line" ]]; then
      echo "prompt file does not follow template at line $((prompt_idx + 1)): expected '$expected_line'" >&2
      return 1
    fi
    prompt_idx=$((prompt_idx + 1))
  done

  instruction_start=$PROMPT_PROTOCOL_INSTRUCTION_INDEX
  instruction_end=$((prompt_line_count - suffix_line_count - 1))
  if (( instruction_end < instruction_start )); then
    echo "prompt file does not follow template: missing instruction block" >&2
    return 1
  fi

  if [[ "$actual_role" == "peer" ]]; then
    required_peer_line="$(prompt_protocol_required_peer_output_line "$prompt_file")"
    if [[ "${prompt_lines[$instruction_start]}" != "$required_peer_line" ]]; then
      echo "peer prompt does not follow template: expected first instruction line '$required_peer_line'" >&2
      return 1
    fi
    required_peer_file="$(prompt_protocol_required_peer_output_file "$prompt_file")"
    if [[ ! -f "$required_peer_file" ]]; then
      echo "peer prompt does not follow protocol: required agent output missing at '$required_peer_file'" >&2
      return 1
    fi
    if ! prompt_protocol_reject_symlink "$required_peer_file" "peer agent output"; then
      return 1
    fi
  fi

  has_instruction_text=0
  local -a severity_levels_seen=()
  local severity_level trimmed_line raw_line content_line next_content
  local fence_char="" fence_len=0
  local fence_marker fence_marker_char fence_marker_len target cell
  local -a cells targets
  for ((prompt_idx = instruction_start; prompt_idx <= instruction_end; prompt_idx++)); do
    if [[ "$actual_role" == "peer" && "$prompt_idx" -eq "$instruction_start" ]]; then
      continue
    fi
    raw_line="${prompt_lines[$prompt_idx]}"
    trimmed_line="$(prompt_protocol_trim "$raw_line")"
    if [[ -n "$trimmed_line" ]]; then
      has_instruction_text=1
    fi

    # Fenced code block tracking. Opener must be >=3 `` ` `` or `~`. Closer must be
    # the same char type and length >= opener's length (CommonMark rule). This
    # prevents `\`\`\`\`md ... \`\`\` ... \`\`\`\`` from being mis-closed by the
    # inner 3-backtick, and keeps `\`\`\`md` + no closer from silently suppressing
    # the rest of the block.
    if [[ "$trimmed_line" =~ ^(\`\`\`+|~~~+) ]]; then
      fence_marker="${BASH_REMATCH[1]}"
      fence_marker_char="${fence_marker:0:1}"
      fence_marker_len=${#fence_marker}
      if [[ -z "$fence_char" ]]; then
        fence_char="$fence_marker_char"
        fence_len=$fence_marker_len
        continue
      fi
      if [[ "$fence_marker_char" == "$fence_char" ]] && (( fence_marker_len >= fence_len )); then
        fence_char=""
        fence_len=0
      fi
      continue
    fi
    if [[ -n "$fence_char" ]]; then
      continue
    fi

    # Indented code block: 4+ leading spaces on a non-blank raw line, outside any
    # fence, is a markdown indented code block—treat as sample prose. Exception:
    # if the trimmed content starts with a list/blockquote/table marker, it's a
    # list continuation (or a table under indentation), NOT an indented code
    # block; fall through to the heuristics so nested bypass attempts like
    # `    - **输出格式**` still get caught.
    if [[ -n "$trimmed_line" ]] && [[ "$raw_line" =~ ^\ {4,} ]]; then
      if ! [[ "$trimmed_line" =~ ^([-*+>]|\[[xX[:space:]]\]|[0-9]+[\.\)])[[:space:]]+ ]] && ! [[ "$trimmed_line" == \|* ]]; then
        continue
      fi
    fi

    # Build the set of content targets to run heuristics against. Strip non-pipe
    # containers first so table detection also works under nested wrapping like
    # `> | cell | **X** |` or `- | cell | **X** |`. Treat any line that contains
    # a `|` outside inline-code as a potential pipe-delimited row (GFM tables
    # without leading/trailing pipes are valid per spec); split into per-cell
    # targets so fixed-section or severity patterns in the 2nd+ column are
    # caught. Inline-code `|`s (e.g. `` `| | **X** |` ``) are ignored so prose
    # that illustrates markdown examples is not mistaken for a real table.
    local nonpipe_stripped pipe_check
    nonpipe_stripped="$(prompt_protocol_strip_nonpipe_containers "$trimmed_line")"
    pipe_check="$(prompt_protocol_strip_inline_code "$nonpipe_stripped")"
    targets=()
    if [[ "$pipe_check" == *"|"* ]]; then
      local IFS_save="$IFS"
      IFS='|' read -r -a cells <<< "$nonpipe_stripped"
      IFS="$IFS_save"
      for cell in "${cells[@]}"; do
        cell="$(prompt_protocol_trim "$cell")"
        if [[ -n "$cell" ]]; then
          targets+=("$(prompt_protocol_strip_containers "$cell")")
        fi
      done
    else
      targets=("$(prompt_protocol_strip_containers "$trimmed_line")")
    fi

    next_content=""
    if (( prompt_idx + 1 <= instruction_end )); then
      next_content="$(prompt_protocol_strip_containers "$(prompt_protocol_trim "${prompt_lines[$((prompt_idx + 1))]}")")"
    fi

    for target in "${targets[@]}"; do
      if (( ${#targets[@]} == 1 )) && [[ "$next_content" =~ ^(=+|-+)$ ]] && [[ "$target" =~ ^(硬性规则|观点级别定义|输出格式|严重度诚实原则)[[:space:]]*$ ]]; then
        echo "prompt file does not follow contract at line $((prompt_idx + 1)): instruction block must not re-declare template-fixed section '${BASH_REMATCH[1]}' via setext heading—it is supplied by the template" >&2
        return 1
      fi

      if [[ "$target" =~ ^#+[[:space:]]+(硬性规则|观点级别定义|输出格式|严重度诚实原则)[[:space:]]*$ ]]; then
        echo "prompt file does not follow contract at line $((prompt_idx + 1)): instruction block must not re-declare template-fixed section '${BASH_REMATCH[1]}'—it is supplied by the template" >&2
        return 1
      fi

      if [[ "$target" =~ ^[\*_]+[[:space:]]*(硬性规则|观点级别定义|输出格式|严重度诚实原则) ]]; then
        echo "prompt file does not follow contract at line $((prompt_idx + 1)): instruction block must not restate '${BASH_REMATCH[1]}' via markdown emphasis—it is supplied by the template" >&2
        return 1
      fi

      # Severity level detection: count the target as a level reference if
      # any of:
      #   (a) the level name is followed by a short tail (≤30 non-colon chars)
      #       then a half- or full-width colon. Covers `Critical: X`,
      #       ``- `[Critical]`：X``, `**Critical**：X`, `Critical（严重）：X`, etc.
      #   (b) the target is exactly a level name with optional wrapping chars
      #       (bare-label table cell like `| Critical |` or `- Critical`).
      if [[ "$target" =~ ^[\`\*_[:space:]\[\(]*(Critical|Major|Minor|Info)[^:：]{0,30}[:：] ]] \
         || [[ "$target" =~ ^[\`\*_[:space:]\[\(]*(Critical|Major|Minor|Info)[\]\)\`\*_[:space:]]*$ ]]; then
        severity_levels_seen+=("${BASH_REMATCH[1]}")
      fi
    done
  done

  if [[ -n "$fence_char" ]]; then
    echo "prompt file does not follow contract: instruction block has an unclosed fenced code block—fence must be closed by the same marker length or longer" >&2
    return 1
  fi
  if (( has_instruction_text == 0 )); then
    echo "prompt file does not follow template: instruction block must not be empty" >&2
    return 1
  fi

  local -A severity_level_counts=()
  for severity_level in "${severity_levels_seen[@]}"; do
    severity_level_counts["$severity_level"]=$((${severity_level_counts["$severity_level"]:-0} + 1))
  done
  local distinct_levels=0
  for severity_level in "${PROMPT_PROTOCOL_SEVERITY_LEVELS[@]}"; do
    if [[ -n "${severity_level_counts[$severity_level]:-}" ]]; then
      distinct_levels=$((distinct_levels + 1))
    fi
  done
  if (( distinct_levels == ${#PROMPT_PROTOCOL_SEVERITY_LEVELS[@]} )); then
    echo "prompt file does not follow contract: instruction block contains all four severity level lines—these belong in the <严重度定义块> slot, not the instruction block" >&2
    return 1
  fi
}
