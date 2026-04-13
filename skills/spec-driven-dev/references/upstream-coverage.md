# Upstream Coverage — 上游契约追溯与覆盖

## 为什么需要上游追溯

spec-driven-dev 的各阶段产物（Plan / Spec / Test / Impl）必须**可追溯到上游契约**（默认 `modeling-first` 的 `model.md` / `epic-model.md`，可替换）。

不做追溯的后果：LLM 会在 Spec/Test/Impl 阶段悄悄忽略上游声明的不变量、引入上游未声明的字段、或把派生值当独立输入——回到建模 skill 要解决的模式匹配问题。

本文档定义 `upstream-ref` 字段的格式、Upstream Coverage Matrix 的结构、机械校验规则。

## upstream-ref 字段规范

### 通用语法

```
upstream-ref: <upstream-doc>#<anchor>[, <upstream-doc>#<anchor>]*
或
upstream-ref: N/A + <具体理由>
```

- `<upstream-doc>`：上游文档的相对路径（如 `model.md`、`../epic-model.md`、`PRD.md`）
- `<anchor>`：上游文档中的稳定锚点，必须以 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释**形式显式声明（机械校验只认这种形式；heading / bold / 纯节标题**不被接受**）
- 多条引用用逗号分隔（一个产出对应多条上游的情况）
- `N/A` 仅当确实不对应任何上游条目（如纯基础设施测试、兼容性回归测试），必须给出理由

### 各阶段的落位

| 阶段 | 产物 | upstream-ref 位置 |
|------|------|-----------------|
| Plan | plan.md 每个模块 | `持有聚合` / `模块依赖` / `产出契约` 字段每项必须以 `<upstream-doc>#<anchor>` 形式指向 Epic 上游契约（见 `workflow-epic.md`）|
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
| <upstream-doc>#<anchor> | <scenario-id> | <file:line> | <file:symbol> | ✅ / ⚠️ NOT APPLICABLE + 理由 |
```

### 必须覆盖的 upstream 条目类型

对于默认路径（modeling-first）：

| upstream 来源 | 应覆盖的内容 |
|-------------|------------|
| model.md Entities | 每个实体的核心属性（尤其是参与不变量或派生的属性） |
| model.md Relationships | 每条关系至少有一个场景/测试验证其基数、所有权或删除语义 |
| model.md Derivation Chains | 每条派生关系必须有测试：输入根变量，断言派生值等于等式结果 |
| model.md Invariants | 每条不变量至少一条断言测试或 property-based 测试 |
| epic-model.md Aggregate 清单 | 每个聚合至少在 Plan 中被某个模块"持有"（Plan 阶段校验） |
| epic-model.md 跨聚合关系 | 每条跨聚合关系在 Plan 的"模块依赖"或"产出契约"中体现（Plan 阶段校验） |

对于替换路径（PRD / DDD / 其他）：

- 上游文档的每一条正式声明（带锚点）都必须进入矩阵
- 若上游文档没有结构化声明（纯自然语言描述），先走替换路径的等效性校验（见 DoR："结构上满足..."）

### NOT APPLICABLE 的判断

允许标注 `⚠️ NOT APPLICABLE + 理由` 的情形：

- 上游条目是**元信息**（如 Epic 的 Context / Source / Date），不是行为/约束
- 上游条目是**非功能性约束**（如性能、合规），由其他 skill（如 `test-quality-gate`）覆盖
- 上游条目描述的是**未来扩展**（标注为 `future` / `out-of-scope`）
- 上游条目对应的**行为本轮 Spec 明确不实现**（已在 Spec 中说明边界）

**不允许**的情形：

- "这条不变量太难测" — 必须测，不变量是硬约束
- "这个派生关系很显然" — 显然也要测，避免偷偷改成独立字段
- "实体 X 本轮用不上" — 那为什么在 upstream 里？要么移除要么覆盖

## 机械校验

参考实现脚本：`../scripts/check-upstream-coverage.sh`

```bash
bash scripts/check-upstream-coverage.sh \
  --upstream docs/models/order.md \
  --matrix docs/coverage/order-coverage.md \
  --refs-glob 'tests/**/*.test.ts,docs/scenarios/**/*.md'

# 回归测试（在修改脚本后 / CI 里常跑）：
bash scripts/check-upstream-coverage.sh --self-test
```

多个上游用逗号分隔：`--upstream docs/models/epic-model.md,docs/models/order.md`

脚本执行以下检查：

### 校验 1：upstream-ref 存在性

扫描所有产物（矩阵 + `--refs-glob` 匹配到的文件）中的 `upstream-ref: <doc>#<anchor>` 和 `@upstream <doc>#<anchor>`，对每条：

1. `<doc>` 能解析到某个 `--upstream` 列表中的已注册上游文件（按绝对路径匹配；basename 相同但路径不同的文件不会被混淆）
2. `<anchor>` 必须以显式 `<!-- anchor: <Name> -->` HTML 注释形式在该上游文档中声明（不接受 markdown heading / 纯加粗文本作为锚点）

任一失败 → CI 失败（exit 2），输出违规清单。

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
