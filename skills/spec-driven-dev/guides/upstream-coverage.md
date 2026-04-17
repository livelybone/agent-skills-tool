# Upstream Coverage — 建模追溯与覆盖

## 为什么需要建模追溯

spec-driven-dev 的 plan，以及下游 worker 产物（tech spec / test / impl）必须**可追溯到建模文件**（`modeling-first` v0.3+ 产出的 `docs/models/<scenario>/<name>.md`）。

不做追溯的后果：LLM 会在 Spec/Test/Impl 阶段悄悄忽略建模声明的不变量、引入建模未声明的字段、或把派生值当独立输入——回到 `modeling-first` 要解决的模式匹配问题。

本文档定义 Upstream Coverage Matrix 的结构和机械校验规则。`upstream-ref` 的语法、锚点命名、N/A 规则、各阶段落位方式见 `upstream-ref.md`（唯一定义点）。

## Upstream Coverage Matrix

### 何时产出

实现完成后，由实现阶段 worker 产出并在交付报告中维护。

### 结构

```
| upstream 条目 | Spec 场景 | Test 位置 | Impl 位置 | 状态 |
|--------------|----------|----------|----------|------|
| <doc>#<anchor> | <scenario-id> | <file:line> | <file:symbol> | ✅ / ⚠️ NOT APPLICABLE + 理由 |
```

### 必须覆盖的建模条目类型

| 来源 | 应覆盖的内容 |
|-------------|------------|
| `domain/<name>.md` Aggregates | 每个聚合锚点至少在 Plan 中被某个模块"持有"（Plan 阶段校验）|
| `domain/<name>.md` Entities | 每个实体（`Entity.*` 锚点）至少有一个场景/测试验证其核心行为；属性级覆盖通过 Invariant / Derivation 锚点间接保证，不要求属性级独立锚点 |
| `domain/<name>.md` Relationships | 每条关系（`Rel.*` 锚点）至少有一个场景/测试验证其基数、所有权或删除语义；跨模块关系必须在 Plan 的"模块依赖"或"产出契约"中体现（`process/<name>.md` 的 `Rel.*` 同等处理）|
| `domain/<name>.md` Derivation Chains | 每条派生关系必须有测试：输入根变量，断言派生值等于等式结果 |
| `domain/<name>.md` Invariants | 每条不变量至少一条断言测试或 property-based 测试；跨模块不变量（`Invariant.*.cross.*`）在执行者模块测 |
| `ui/<name>.md` / `components/<family>.md` | Entity（视图模型）、Component、Derivation、Invariant、StateMachine 各自对应 UI 场景/组件测试；Component 的视觉派生映射到视觉回归 |
| `process/<name>.md` | Process 主体对应端到端场景；Rel 对应跨模块契约验证；Invariant 对应流程内约束测试 |
| `state-machine/<name>.md` | StateMachine 覆盖状态转换路径；Invariant 覆盖状态机约束 |

### NOT APPLICABLE 的判断

允许标注 `⚠️ NOT APPLICABLE + 理由` 的情形：

- 建模条目是**元信息**（如单元头部的 Context / Source / Date），不是行为/约束
- 建模条目是**非功能性约束**（如性能、合规），由其他 skill（如 `test-quality-gate`）覆盖
- 建模条目描述的是**未来扩展**（标注为 `future` / `out-of-scope`）
- 建模条目对应的**行为本轮 Spec 明确不实现**（已在 Spec 中说明边界）

**不允许**的情形：

- "这条不变量太难测" — 必须测，不变量是硬约束
- "这个派生关系很显然" — 显然也要测，避免偷偷改成独立字段
- "实体 X 本轮用不上" — 那为什么在建模里？要么移除要么覆盖

## 机械校验

参考实现脚本：`../scripts/check-upstream-coverage.sh`

```bash
bash scripts/check-upstream-coverage.sh \
  --upstream docs/models/domain/order.md \
  --matrix docs/coverage/order-coverage.md \
  --refs-glob 'tests/**/*.test.ts,docs/scenarios/**/*.md'

# 回归测试（在修改脚本后 / CI 里常跑）：
bash scripts/check-upstream-coverage.sh --self-test
```

多个建模文件用逗号分隔：`--upstream docs/models/domain/order.md,docs/models/ui/order.md`

**路径约束**（与 `modeling-first` 的硬耦合）：`--upstream` 指向的文件路径必须以 `<scenario>/<name>.md` 结尾，其中 `<scenario>` 是固定 5 个 scenario 之一（`domain` / `ui` / `components` / `process` / `state-machine`），`<name>` 是 kebab-case。其他路径一律被脚本拒绝（exit 1）。

**身份解析**：refs 通过最后两段路径（`<scenario>/<name>.md`）与注册的 upstream 匹配——支持 `docs/models/domain/order.md#...` 与 `domain/order.md#...` 两种写法都能解析到同一 upstream。单次运行中不允许两个 `--upstream` 共享同一身份（即 `<scenario>/<name>`），否则 exit 1。

### Epic 多模块场景的调用方式

Epic 涉及多个建模单元（scenario × name 组合），需**按身份分别运行**。身份在同次运行内必须唯一（如 `domain/order.md` + `domain/payment.md` 可共存；`order/domain/order.md` + `other/domain/order.md` 不可共存——后两者身份都是 `domain/order.md`）。

**Shell loop 示例**：

```bash
#!/usr/bin/env bash
set -euo pipefail

# 建模单元清单：<scenario>/<name>
UNITS=(
  domain/order
  domain/payment
  domain/notification
  ui/order-dashboard
  process/refund
)
FAILED=()

# 1a. Plan 结构校验 + 聚合落位（Epic 场景硬性）
#     --upstream 的语义是"Epic 涉及的所有聚合来源单元"，**必须包含尚未被 Plan
#     引用的 domain 单元**——仅传入"Plan 引用的单元"会放过"某聚合所在单元整
#     个未被任何模块持有"的失配。
bash scripts/check-plan-structure.sh \
  --plan docs/plan.md \
  --upstream docs/models/domain/order.md,docs/models/domain/payment.md,docs/models/domain/notification.md \
  || FAILED+=(plan-structure)

# 1b. Plan 锚点存在性（按 Plan 实际引用的单元注册）
#     通常是 domain 单元；Plan 中有契约来自 process 单元的 Rel.* 时，也需注册
#     （按 modeling-first/references/cross-module.md 权威：Rel 位于引用方单元）
bash scripts/check-upstream-coverage.sh \
  --upstream docs/models/domain/order.md,docs/models/domain/payment.md,docs/models/domain/notification.md,docs/models/process/refund.md \
  --matrix docs/coverage/plan-coverage.md \
  --refs-glob 'docs/plan.md' || FAILED+=(plan-refs)

# 2. 按单元逐个校验（每个单元独立运行，可跨 scenario 共存但需身份唯一）
for unit in "${UNITS[@]}"; do
  scenario="${unit%%/*}"
  name="${unit##*/}"
  echo "=== Checking unit: $unit ==="
  bash scripts/check-upstream-coverage.sh \
    --upstream "docs/models/${scenario}/${name}.md" \
    --matrix "docs/coverage/${scenario}-${name}-coverage.md" \
    --refs-glob "tests/${name}/**/*.test.ts,docs/scenarios/${name}/**/*.md,spec/${name}*.md" \
    || FAILED+=("$unit")
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "❌ Upstream coverage failed for: ${FAILED[*]}"
  exit 1
fi
echo "✅ All units passed upstream coverage check"
```

**Makefile target 示例**：

```makefile
UNITS := domain/order domain/payment domain/notification ui/order-dashboard process/refund

.PHONY: upstream-coverage
upstream-coverage:
	@for unit in $(UNITS); do \
	  scenario=$${unit%%/*}; \
	  name=$${unit##*/}; \
	  echo "=== Checking unit: $$unit ==="; \
	  bash scripts/check-upstream-coverage.sh \
	    --upstream "docs/models/$${scenario}/$${name}.md" \
	    --matrix "docs/coverage/$${scenario}-$${name}-coverage.md" \
	    --refs-glob "tests/$${name}/**/*.test.ts,docs/scenarios/$${name}/**/*.md,spec/$${name}*.md"; \
	done
```

脚本执行以下检查：

### 校验 1：upstream-ref 存在性

扫描所有产物（矩阵 + `--refs-glob` 匹配到的文件）中的 `upstream-ref: <doc>#<anchor>` 和 `@upstream <doc>#<anchor>`，对每条：

1. `<doc>` 的最后两段路径必须匹配 `<scenario>/<name>.md`，且 scenario 是 5 个固定 scenario 之一，且能通过身份匹配到某个 `--upstream` 列表中的已注册文件（**按身份匹配**——完整路径前缀仅作人类可读提示，脚本不校验其正确性；这让模块重构/移动不破坏历史 refs，但也意味着过期路径前缀不会被自动发现）。**单次运行中不允许两个 `--upstream` 文件共享同一身份**，否则脚本在加载阶段直接 exit 1；多单元场景需按身份分别注册
2. `<anchor>` 必须匹配形状正则 `[A-Z][A-Za-z0-9]*\.[A-Za-z0-9._-]+`（大驼峰前缀 + `.` + 名字），且以 `<!-- anchor: <Name> -->` HTML 注释形式在该建模文件中声明（不接受 markdown heading / 纯加粗文本作为锚点）。**命名空间合法性**（前缀是否属于当前约定类别、是否适配对应 scenario）由 `prompts/upstream-review.md` 的建模审查兜底——脚本只做形状 + 存在性校验，`modeling-first` 扩展命名空间时无需改脚本

由于锚点正则不包含括号/标点，嵌在中英文括号/逗号/句号中的引用会在正则层面自然截断，脚本不做额外剥离。任一失败 → CI 失败（exit 2），输出违规清单。

### 校验 2：上游覆盖率

扫描上游文档的所有锚点，对每个锚点：

1. 在 Upstream Coverage Matrix 中必须能找到对应行
2. 对应行状态必须是 `✅` 或 `⚠️ NOT APPLICABLE + <非空理由>`
   - **只接受 `+` 作为理由分隔符**；冒号 `:` 不被接受（避免与 `doc:anchor` 引用产生歧义）
   - 理由必须非空（至少一个非空白字符）

任一缺失或状态无效 → CI 失败（exit 3）。

### 校验 3：矩阵引用真实性

矩阵的每个 Spec/Test/Impl 位置都必须真实存在。允许两种格式：

1. **`file.ext:<lineno>`** — 整数行号，必须满足 `1 <= lineno <= 文件行数`
2. **`file.ext:<identifier>`** — 单一标识符（正则 `^[A-Za-z_][A-Za-z0-9_]*$`），按全词匹配在文件中出现

**复杂符号**（含空格、括号、点号等，如 `get total()`、`Class.method`）**必须**用行号形式，不得写为 symbol——否则被视为 INVALID SUFFIX（防止因截断导致的误匹配）。

虚假引用 / 无效行号 / 无效后缀 → CI 失败（exit 4）。

### 脚本边界（必读）

`check-upstream-coverage.sh` 是**位置存在性**校验，不是**语义对齐**校验：

- ✅ 脚本校验：锚点是否在上游建模文件中以 `<!-- anchor: ... -->` 注释声明；`upstream-ref` 引用的 `doc#anchor` 是否存在；矩阵每个锚点是否有行；矩阵每个 file:line / file:symbol 是否真实存在于文件
- ❌ 脚本**不**校验：矩阵里指向的 file:line 处的代码/测试是否真正承载了对应锚点的领域语义（如 `Invariant.Order.3` 指向 `src/order.ts:42` 时，脚本不会验证第 42 行真的实现了该不变量）

语义对齐的兜底在多层：

1. **跨 agent 审查**（Spec/Scenario/Test review prompts 的"上游对齐检查"节）——人/agent 读代码和锚点比对
2. **测试本身**——测试名、断言对应锚点语义，Red Run 要求全红证明锚点行为尚未实现
3. **人工 / Auto 裁决审查阶段**——Coverage Matrix Review 时必须至少抽样校对几条高风险条目的语义对齐

因此：位置存在性的 fail-closed 保证上游条目不被"悄悄漏掉"，语义对齐由审查链承担。agent 不得以"脚本通过了"为由跳过语义对齐审查。

### 校验 0：矩阵预处理（fail-closed）

在三项正式校验前，脚本会先对矩阵做一次 HTML 注释剥离。以下结构被视为 malformed，直接失败（exit 5）：

- 嵌套注释：`<!-- outer <!-- inner --> outer -->`
- 未闭合注释：文件末尾仍处于 `<!--` 打开状态
- 散落的闭合：`-->` 没有对应的 `<!--`

目的是防止 matrix 被故意或无意地用畸形注释隐藏/伪造 ref。

## 与 Workflow Summary 的关系

Auto 模式下，每次 upstream 回修（见 `workflows/epic.md`）必须记入编排层的变更记录；Upstream Coverage Matrix 也必须随之更新。

workflow summary 应包含：

- 最终的 Upstream Coverage Matrix
- upstream 回修次数和每次的原因
- NOT APPLICABLE 条目清单及理由
