# Upstream Coverage — 建模追溯与覆盖

## 为什么需要建模追溯

spec-driven-dev 的各阶段产物（Plan / Spec / Test / Impl）必须**可追溯到建模文件**（`modeling-first` 产出的 `model.md` / `epic-model.md`）。

不做追溯的后果：LLM 会在 Spec/Test/Impl 阶段悄悄忽略建模声明的不变量、引入建模未声明的字段、或把派生值当独立输入——回到 `modeling-first` 要解决的模式匹配问题。

本文档定义 `upstream-ref` 字段的格式、Upstream Coverage Matrix 的结构、机械校验规则。

## upstream-ref 字段规范

### 通用语法

```
upstream-ref: <doc>#<anchor>[, <doc>#<anchor>]*
或
upstream-ref: N/A + <具体理由>
```

- `<doc>`：建模文件的相对路径，**只接受** `model.md` / `epic-model.md` 两种文件名（可带路径前缀如 `../epic-model.md`）。其他文件名一律视为无效引用
- `<anchor>`：建模文件中的锚点，必须以 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释**形式显式声明（机械校验只认这种形式；heading / bold / 纯节标题**不被接受**）。命名空间固定为：`Entity` / `Rel` / `Invariant` / `Derivation` / `Aggregate` / `SharedInvariant`
- 多条引用用逗号分隔（一个产出对应多条建模锚点的情况）
- `N/A` 仅当确实不对应任何建模条目（如纯基础设施测试、兼容性回归测试），必须给出理由

### 各阶段的落位

| 阶段 | 产物 | upstream-ref 位置 |
|------|------|-----------------|
| Plan | plan.md 每个模块 | `持有聚合` / `模块依赖` / `产出契约` 字段每项必须以 `epic-model.md#<anchor>` 形式指向 `epic-model.md`（见 `workflow-epic.md`）|
| Spec | 业务规范（spec.md）| 每条 Rule / State / State Transition 末尾加行内标注 `（upstream-ref: <doc>#<anchor>）`；若确实没有对应上游条目，标 `（upstream-ref: N/A + 理由）`|
| Scenario | 场景清单 | 每个场景末尾用 `↑ upstream-ref: ...`（见 `scenario-format.md`） |
| Test | 测试用例 | 测试顶部注释 `@upstream ...` 或测试名前缀（见 `prompt-test-implementation.md`） |
| Impl | 实现代码 | 关键位置注释 `// covers <upstream-ref>`；详细追溯由 Upstream Coverage Matrix 承载，不必每行都标 |
| Coverage Matrix | `<module>/coverage.md` | 每条 upstream 条目占一行，列出对应的 Spec / Test / Impl 位置 |

## Upstream Coverage Matrix

### 何时产出

实现完成后（见 `prompt-feature-implementation.md` 的 Spec 完整性 + Upstream Coverage 校验步骤）。

### 结构

```
| upstream 条目 | Spec 场景 | Test 位置 | Impl 位置 | 状态 |
|--------------|----------|----------|----------|------|
| <doc>#<anchor> | <scenario-id> | <file:line> | <file:symbol> | ✅ / ⚠️ NOT APPLICABLE + 理由 |
```

### 必须覆盖的建模条目类型

| 来源 | 应覆盖的内容 |
|-------------|------------|
| model.md Entities | 每个实体的核心属性（尤其是参与不变量或派生的属性） |
| model.md Relationships | 每条关系至少有一个场景/测试验证其基数、所有权或删除语义 |
| model.md Derivation Chains | 每条派生关系必须有测试：输入根变量，断言派生值等于等式结果 |
| model.md Invariants | 每条不变量至少一条断言测试或 property-based 测试 |
| epic-model.md Aggregate 清单 | 每个聚合至少在 Plan 中被某个模块"持有"（Plan 阶段校验） |
| epic-model.md 跨聚合关系 | 每条跨聚合关系在 Plan 的"模块依赖"或"产出契约"中体现（Plan 阶段校验） |
| epic-model.md SharedInvariants | 每条共享不变量至少在一个模块的 Spec/Test 中体现 |

### NOT APPLICABLE 的判断

允许标注 `⚠️ NOT APPLICABLE + 理由` 的情形：

- 建模条目是**元信息**（如 Epic 的 Context / Source / Date），不是行为/约束
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
  --upstream docs/models/order/model.md \
  --matrix docs/coverage/order-coverage.md \
  --refs-glob 'tests/**/*.test.ts,docs/scenarios/**/*.md'

# 回归测试（在修改脚本后 / CI 里常跑）：
bash scripts/check-upstream-coverage.sh --self-test
```

多个建模文件用逗号分隔：`--upstream docs/models/epic-model.md,docs/models/order/model.md`

**文件名约束**：`--upstream` 指向的文件 basename 必须是 `model.md` 或 `epic-model.md`；其他 basename 拒绝加载（exit 1）。这是与 `modeling-first` 的硬耦合，消除"等效文档"的语义歧义。

### Epic 多模块场景的调用方式

由于单次运行不允许两个 `--upstream` 文件共享同一 basename（如 `order/model.md` + `payment/model.md` 都叫 `model.md`），Epic 多模块场景需**按模块分别运行**。

**Shell loop 示例**：

```bash
#!/usr/bin/env bash
set -euo pipefail

EPIC_MODEL="docs/models/epic-model.md"
MODULES=(order payment notification)
FAILED=()

# 1. 校验 epic-model 自身（用 epic-model.md 作为 upstream，校验 Plan 级引用）
bash scripts/check-upstream-coverage.sh \
  --upstream "$EPIC_MODEL" \
  --matrix docs/coverage/epic-coverage.md \
  --refs-glob 'docs/plan.md' || FAILED+=(epic)

# 2. 按模块逐个校验
for mod in "${MODULES[@]}"; do
  echo "=== Checking module: $mod ==="
  bash scripts/check-upstream-coverage.sh \
    --upstream "docs/models/${mod}/model.md" \
    --matrix "docs/coverage/${mod}-coverage.md" \
    --refs-glob "tests/${mod}/**/*.test.ts,docs/scenarios/${mod}/**/*.md,spec/${mod}*.md" \
    || FAILED+=("$mod")
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "❌ Upstream coverage failed for: ${FAILED[*]}"
  exit 1
fi
echo "✅ All modules passed upstream coverage check"
```

**Makefile target 示例**：

```makefile
MODULES := order payment notification

.PHONY: upstream-coverage
upstream-coverage:
	bash scripts/check-upstream-coverage.sh \
	  --upstream docs/models/epic-model.md \
	  --matrix docs/coverage/epic-coverage.md \
	  --refs-glob 'docs/plan.md'
	@for mod in $(MODULES); do \
	  echo "=== Checking module: $$mod ==="; \
	  bash scripts/check-upstream-coverage.sh \
	    --upstream "docs/models/$$mod/model.md" \
	    --matrix "docs/coverage/$$mod-coverage.md" \
	    --refs-glob "tests/$$mod/**/*.test.ts,docs/scenarios/$$mod/**/*.md,spec/$$mod*.md"; \
	done
```

脚本执行以下检查：

### 校验 1：upstream-ref 存在性

扫描所有产物（矩阵 + `--refs-glob` 匹配到的文件）中的 `upstream-ref: <doc>#<anchor>` 和 `@upstream <doc>#<anchor>`，对每条：

1. `<doc>` 的 basename 必须是 `model.md` 或 `epic-model.md`，且能解析到某个 `--upstream` 列表中的已注册文件（**按 basename 匹配**——路径前缀仅作人类可读提示，脚本不校验其正确性；这让模块重构/移动不破坏历史 refs，但也意味着过期路径前缀不会被自动发现）。**单次运行中不允许两个 `--upstream` 文件共享同一 basename**（如同时注册 `order/model.md` + `payment/model.md`），否则脚本在加载阶段直接 exit 1；多模块场景需按模块分别运行
2. `<anchor>` 必须匹配严格的命名空间正则 `(Entity|Rel|Invariant|Derivation|Aggregate|SharedInvariant)\.[A-Za-z0-9._-]+`，且以 `<!-- anchor: <Name> -->` HTML 注释形式在该建模文件中声明（不接受 markdown heading / 纯加粗文本作为锚点）

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

### 校验 0：矩阵预处理（fail-closed）

在三项正式校验前，脚本会先对矩阵做一次 HTML 注释剥离。以下结构被视为 malformed，直接失败（exit 5）：

- 嵌套注释：`<!-- outer <!-- inner --> outer -->`
- 未闭合注释：文件末尾仍处于 `<!--` 打开状态
- 散落的闭合：`-->` 没有对应的 `<!--`

目的是防止 matrix 被故意或无意地用畸形注释隐藏/伪造 ref。

## 与 Decision Log 的关系

Auto 模式下，每次 upstream 回修（见 `workflow-epic.md` 的"迭代回流规则"）必须记入 `upstream-change-log.md`；Upstream Coverage Matrix 也必须随之更新。

Decision Report 输出时包含：

- 最终的 Upstream Coverage Matrix
- upstream 回修次数和每次的原因
- NOT APPLICABLE 条目清单及理由
