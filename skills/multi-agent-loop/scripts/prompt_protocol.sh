#!/usr/bin/env bash

PROMPT_PROTOCOL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_PROTOCOL_TEMPLATE_FILE="$PROMPT_PROTOCOL_SCRIPT_DIR/../templates/agent-prompt.txt"
PROMPT_PROTOCOL_TEMPLATE_LOADED=0

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
    fi
  done

  if [[ "$PROMPT_PROTOCOL_TYPE_INDEX" -lt 0 || "$PROMPT_PROTOCOL_ROLE_INDEX" -lt 0 || "$PROMPT_PROTOCOL_INSTRUCTION_INDEX" -lt 0 ]]; then
    echo "prompt template is invalid: missing type, role, or instruction placeholder" >&2
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
  prompt_line_count=${#prompt_lines[@]}
  template_line_count=${#PROMPT_PROTOCOL_TEMPLATE_LINES[@]}
  prefix_line_count=$PROMPT_PROTOCOL_INSTRUCTION_INDEX
  suffix_line_count=$((template_line_count - PROMPT_PROTOCOL_INSTRUCTION_INDEX - 1))

  if (( prompt_line_count < template_line_count )); then
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

  for ((template_idx = PROMPT_PROTOCOL_INSTRUCTION_INDEX + 1; template_idx < template_line_count; template_idx++)); do
    prompt_idx=$((prompt_line_count - suffix_line_count + template_idx - PROMPT_PROTOCOL_INSTRUCTION_INDEX - 1))
    expected_line="${PROMPT_PROTOCOL_TEMPLATE_LINES[$template_idx]}"
    if [[ "${prompt_lines[$prompt_idx]}" != "$expected_line" ]]; then
      echo "prompt file does not follow template at line $((prompt_idx + 1)): expected '$expected_line'" >&2
      return 1
    fi
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
  for ((prompt_idx = instruction_start; prompt_idx <= instruction_end; prompt_idx++)); do
    if [[ "$actual_role" == "peer" && "$prompt_idx" -eq "$instruction_start" ]]; then
      continue
    fi
    if [[ -n "$(prompt_protocol_trim "${prompt_lines[$prompt_idx]}")" ]]; then
      has_instruction_text=1
      break
    fi
  done
  if (( has_instruction_text == 0 )); then
    echo "prompt file does not follow template: instruction block must not be empty" >&2
    return 1
  fi
}

prompt_protocol_render_prompt_stdin() {
  local prompt_type="$1"
  local prompt_role="$2"
  local output_file="$3"
  local idx line has_instruction_text required_peer_line
  local -a instruction_lines=()

  prompt_protocol_load_template || return 1

  if ! prompt_protocol_value_allowed "$prompt_type" "${PROMPT_PROTOCOL_ALLOWED_TYPES[@]}"; then
    echo "prompt type '$prompt_type' is not allowed by template" >&2
    return 1
  fi
  if ! prompt_protocol_value_allowed "$prompt_role" "${PROMPT_PROTOCOL_ALLOWED_ROLES[@]}"; then
    echo "prompt role '$prompt_role' is not allowed by template" >&2
    return 1
  fi

  has_instruction_text=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    instruction_lines+=("$line")
    if [[ -n "$(prompt_protocol_trim "$line")" ]]; then
      has_instruction_text=1
    fi
  done
  if (( has_instruction_text == 0 )); then
    echo "instruction stdin must not be empty" >&2
    return 1
  fi

  if [[ "$prompt_role" == "peer" ]]; then
    required_peer_line="$(prompt_protocol_required_peer_output_line "$output_file")"
    instruction_lines=("$required_peer_line" "" "${instruction_lines[@]}")
  fi

  mkdir -p "$(dirname "$output_file")"
  if ! prompt_protocol_reject_symlink "$output_file" "prompt file"; then
    return 1
  fi
  : > "$output_file"

  for idx in "${!PROMPT_PROTOCOL_TEMPLATE_LINES[@]}"; do
    line="${PROMPT_PROTOCOL_TEMPLATE_LINES[$idx]}"
    if [[ "$idx" -eq "$PROMPT_PROTOCOL_TYPE_INDEX" ]]; then
      printf '%s\n' "- 类型：$prompt_type" >> "$output_file"
    elif [[ "$idx" -eq "$PROMPT_PROTOCOL_ROLE_INDEX" ]]; then
      printf '%s\n' "- 角色：$prompt_role" >> "$output_file"
    elif [[ "$idx" -eq "$PROMPT_PROTOCOL_INSTRUCTION_INDEX" ]]; then
      for line in "${instruction_lines[@]}"; do
        printf '%s\n' "$line" >> "$output_file"
      done
    else
      printf '%s\n' "$line" >> "$output_file"
    fi
  done

  prompt_protocol_validate_prompt_file "$output_file" "$prompt_role"
}
