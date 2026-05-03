#!/usr/bin/env bash
# check-adr-conditions.sh —— 三条件 AND gate 机械校验
#
# 用法:
#   check-adr-conditions.sh <draft.md>          # 校验单个 ADR draft
#   check-adr-conditions.sh --self-test         # 跑内置 4 场景自测
#
# 契约:
#   - 退出码 0 == 三条件全部 PASS
#   - 退出码非零 == 至少一条不满足,stderr 给出 FAIL 原因
#   - PASS 判定:frontmatter 中 irreversibility / surprise-without-context / real-tradeoff
#     三字段非空,且不仅含模板占位符(< / TODO / 反例: 等空话)
#
# 承载:
#   skills/adr-recorder/SKILL.md §3.1 Gate 步骤
#   Invariant.AdrRecorderSkill.1(三条件 AND gate)

set -euo pipefail

# ---------- 工具函数 ----------

extract_yaml_block() {
  # 把 frontmatter 块抽出来(--- 之间的内容);若无则 stdout 空
  local file="$1"
  awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print}' "$file"
}

# 抽出某个 yaml field 的内容(支持 "x: |" 多行 block scalar 与单行)
extract_field() {
  local yaml="$1" field="$2"
  # 多行 block 情况:"field: |" 后面缩进的若干行
  echo "$yaml" | awk -v key="$field" '
    BEGIN { in_block=0; block_indent=-1 }
    {
      # 单行: "field: value"
      if ($0 ~ "^"key":[[:space:]]") {
        sub("^"key":[[:space:]]*", "", $0)
        # 去引号
        gsub(/^["'\'']|["'\'']$/, "", $0)
        # 单行值
        if ($0 != "" && $0 != "|") { print $0 }
        if ($0 == "|") { in_block=1; block_indent=-1 }
        next
      }
      if (in_block) {
        # 检测当前行是否还在缩进 block 内(空行或缩进 >0 算 block 内容)
        if ($0 ~ /^[[:space:]]/ || $0 == "") {
          if (block_indent < 0 && $0 ~ /^[[:space:]]/) {
            # 第一行确定缩进
            match($0, /^[[:space:]]+/)
            block_indent = RLENGTH
          }
          # 去掉前导缩进
          sub(/^[[:space:]]+/, "", $0)
          print $0
        } else {
          # 遇到非缩进行(下一个 key 或 ---),退出 block
          in_block=0
        }
      }
    }
  '
}

# 判定值是否"实质非空"——不只是占位符/TODO
is_meaningful() {
  local raw="$1"
  # 把多行内容拼成一行(用空格替代换行)便于做整体占位检测,但同时保留逐行清洗
  local joined
  joined=$(echo "$raw" | tr '\n' ' ')

  # 整体占位检测:若整段(去首尾空白后)以 < 开头且以 > 结尾,视为单一占位 block
  local trimmed
  trimmed=$(echo "$joined" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  if [[ -z "$trimmed" ]]; then
    return 1
  fi
  # 整体仅由一个 <...> 占位组成(可跨行),且其内不嵌另一个完整的 <...> 实义短语 → 视为占位
  if [[ "$trimmed" =~ ^\<.*\>$ ]]; then
    # 去除 < 与 > 后若仅剩"反例:..." / "TODO" / 空白 / 模板指引,视为空
    local inner
    inner=$(echo "$trimmed" | sed -E 's/^<//; s/>$//')
    inner=$(echo "$inner" | sed -E 's/反例[:：][^。]*。?//g; s/TODO//g; s/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//')
    if [[ -z "$inner" || "$inner" =~ ^[[:punct:][:space:]]+$ ]]; then
      return 1
    fi
    # 整体被 <> 包住但 inner 仍含真实文字也算占位(模板指引语境)
    return 1
  fi

  # 逐行清洗:去空行、单行 <...> 占位、TODO、反例: 指引行
  local cleaned
  cleaned=$(echo "$raw" | sed -E '
    s/^[[:space:]]+//;
    s/[[:space:]]+$//;
    /^$/d;
    /^反例[:：]/d;
    /^[[:space:]]*<[^>]*>[[:space:]]*$/d;
    /^[[:space:]]*TODO[[:space:]]*$/d;
  ')
  if [[ -z "$cleaned" ]]; then
    return 1
  fi
  return 0
}

check_one_field() {
  local yaml="$1" field="$2"
  local val
  val=$(extract_field "$yaml" "$field" || true)
  if is_meaningful "$val"; then
    echo "  PASS  $field"
    return 0
  else
    echo "  FAIL  $field (空 / 仅占位符 / 仅指引文本)" >&2
    return 1
  fi
}

check_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return 2
  fi
  local yaml
  yaml=$(extract_yaml_block "$file")
  if [[ -z "$yaml" ]]; then
    echo "ERROR: no frontmatter detected in $file" >&2
    return 2
  fi

  echo "Checking: $file"
  local rc=0
  check_one_field "$yaml" "irreversibility" || rc=1
  check_one_field "$yaml" "surprise-without-context" || rc=1
  check_one_field "$yaml" "real-tradeoff" || rc=1

  if [[ "$rc" -eq 0 ]]; then
    echo "RESULT: ALL THREE CONDITIONS PASS"
  else
    echo "RESULT: GATE BLOCKED — 至少一条三条件不满足,不允许进入 Draft" >&2
  fi
  return $rc
}

# ---------- self-test ----------

self_test() {
  local tmp
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  # 场景 1:三条件齐备 → 期望 PASS
  cat >"$tmp/ok.md" <<'EOF'
---
id: 0001
title: "switch event bus to Kafka"
status: proposed
date: 2026-05-03
irreversibility: |
  回滚成本约 2 周:订单与库存服务的消费者已切到 Kafka topic,
  回滚需要双写 + 数据补偿,影响线上 SLA。
surprise-without-context: |
  6 个月后新人会问:为什么不继续用 RabbitMQ?这就是上下文要回答的。
real-tradeoff: |
  备选 A: 保留 RabbitMQ + 手工分区,被否(顺序保证差);
  备选 B: 用 Pulsar,被否(运维栈不熟悉,无现成监控)。
---
# body
EOF

  # 场景 2:irreversibility 缺失 → 期望 FAIL
  cat >"$tmp/no-irrev.md" <<'EOF'
---
id: 0002
title: "x"
status: proposed
date: 2026-05-03
irreversibility: |
  <回滚成本量化(钱/人时/数据迁移规模/对外契约破坏)>
surprise-without-context: |
  6 个月后会问 why。
real-tradeoff: |
  备选 A,被否;备选 B,被否。
---
EOF

  # 场景 3:surprise-without-context 仅含占位 → 期望 FAIL
  cat >"$tmp/no-surprise.md" <<'EOF'
---
id: 0003
title: "y"
status: proposed
date: 2026-05-03
irreversibility: |
  回滚 2 周。
surprise-without-context: |
  TODO
real-tradeoff: |
  备选 A,被否;备选 B,被否。
---
EOF

  # 场景 4:real-tradeoff 空 → 期望 FAIL
  cat >"$tmp/no-tradeoff.md" <<'EOF'
---
id: 0004
title: "z"
status: proposed
date: 2026-05-03
irreversibility: |
  回滚 2 周。
surprise-without-context: |
  6 个月后会问 why。
real-tradeoff: |
---
EOF

  echo "=== self-test 1: all three present (expect PASS) ==="
  if check_file "$tmp/ok.md"; then
    echo "  ✓ scenario 1 OK"
  else
    echo "  ✗ scenario 1 FAILED — gate should have passed" >&2
    return 1
  fi
  echo

  echo "=== self-test 2: missing irreversibility (expect FAIL) ==="
  if check_file "$tmp/no-irrev.md" 2>/dev/null; then
    echo "  ✗ scenario 2 FAILED — gate should have blocked" >&2
    return 1
  else
    echo "  ✓ scenario 2 OK (gate blocked as expected)"
  fi
  echo

  echo "=== self-test 3: surprise-without-context only TODO (expect FAIL) ==="
  if check_file "$tmp/no-surprise.md" 2>/dev/null; then
    echo "  ✗ scenario 3 FAILED — gate should have blocked" >&2
    return 1
  else
    echo "  ✓ scenario 3 OK (gate blocked as expected)"
  fi
  echo

  echo "=== self-test 4: real-tradeoff empty (expect FAIL) ==="
  if check_file "$tmp/no-tradeoff.md" 2>/dev/null; then
    echo "  ✗ scenario 4 FAILED — gate should have blocked" >&2
    return 1
  else
    echo "  ✓ scenario 4 OK (gate blocked as expected)"
  fi
  echo

  echo "ALL 4 SELF-TEST SCENARIOS PASSED"
  return 0
}

# ---------- main ----------

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <draft.md>" >&2
  echo "       $0 --self-test" >&2
  exit 2
fi

if [[ "$1" == "--self-test" ]]; then
  self_test
  exit $?
fi

check_file "$1"
exit $?
