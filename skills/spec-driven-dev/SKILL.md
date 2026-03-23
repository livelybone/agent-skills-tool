---
name: spec-driven-dev
description: 强制执行规范驱动的 AI 开发工作流。Epic 级需求先 Plan（模块拆解 + 依赖图 + 契约定义），再对每个模块独立走 Spec → Scenarios → Tests → Implementation → CI 流程。控制行为、减少回归，确保 AI 生成的代码与业务规则一致。使用 multi-agent-loop 提供独立的跨 agent 审查。触发词：spec、plan、epic、模块拆解、开发规范、需求拆分。
metadata:
  version: 1.3
  tags:
    - ai-workflow
    - spec-driven
    - epic-planning
    - testing
    - development-process
---

# 规范驱动开发 Skill

## 目的

本 skill 强制执行 AI 辅助软件开发的结构化工作流，覆盖两个层次：

**Epic 层（需求超出单个模块时必须先执行）**：

Plan（模块拆解 + 依赖图 + 契约定义）
→ Human Plan Review（人确认边界与依赖）
→ 对每个模块独立启动下方的 Spec 层流程

**Spec 层（每个模块独立执行）**：

Spec（规范）
→ AI-Assisted Spec Review（跨 agent 审查，可选）
→ Human Spec Review（人工 Spec 审查）
→ Scenario Generation（场景生成）
→ AI-Assisted Scenario Review（跨 agent 审查，可选）
→ Human Scenario Review（人工场景审查）
→ Test Implementation（测试实现）
→ AI-Assisted Test Review（跨 agent 对照审查，可选）
→ Human Test Review（人工测试审查，可选）
→ Feature Implementation（功能实现）
→ CI Verification（CI 验证）

工作流确保：

- 行为在实现之前被定义
- Spec 的质量在源头得到保证（完整性、一致性、无歧义）
- AI 提供独立的审查视角（通过 `multi-agent-loop` 跨 agent 审查）
- 关键场景由人工审查
- 测试在实现前经过对照审查，验证 scenario → test 翻译正确性
- AI 执行大部分实现工作
- CI 强制执行正确性

---

# 核心原则

- Spec 是唯一的真理源
- 人类定义行为；AI 执行
- 测试场景是人类可读的
- 测试代码由 AI 生成
- 实现必须满足测试
- CI 是最终强制层
- 优先行为验证而非实现测试
- 优先少量高价值测试而非大量脆弱测试套件

---

# 人机分工

## 人的职责

- 定义/审查行为（Spec + Scenario）
- **不管代码**

具体：

- 编写或审查 Spec
- 审查 AI 生成的 Scenario
- 验证业务覆盖度
- 批准最终行为

## AI 的职责

- 执行（生成 Scenario、写 Test、写 Feature）

具体：

- 从 Spec 生成 Scenario
- 编写自动化测试
- 实现功能
- 建议遗漏的边界案例
- 暴露 Spec 的歧义

## 测试的职责

- 保证 AI 生成的代码符合人审查的场景

## 质量保证链条

```
Spec (人定义/审查)
→ Scenario (AI 生成 + 人审查)
→ Test (AI 实现)
→ Test Review (跨 agent 对照审查 + 人审查，按复杂度可选)
→ Feature (AI 实现，满足测试)
→ CI (自动验证)
```

每一层都有验证，**人只需要在关键决策点（行为定义）介入**。

---

# 复杂度分级标准

根据任务复杂度，调整**谁来主导 Spec 编写**和**各审查环节的深度**。

完整流程（每个模块）：

```
1. Spec 生成
2. AI 辅助审查 Spec ← 按复杂度可选
3. 人工 Spec 审查
4. Scenario 生成
5. AI 辅助审查 Scenario ← 按复杂度可选
6. 人工 Scenario 审查
7. Test Implementation
8. AI 辅助审查 Test ← 按复杂度可选
9. 人工 Test 审查 ← 按复杂度可选
10. Feature Implementation
11. CI Verification
```

步骤 7、10、11 不随复杂度变化，始终执行。各级别的可变步骤策略如下：

| 步骤 | Trivial | Simple | Medium | Complex |
|------|---------|--------|--------|---------|
| **Spec 生成** | 人口头描述 → AI 生成 | 人简要描述 → AI 生成 | 人编写初稿 → AI 补充 | 人编写初稿 → AI 补充 |
| **AI 辅助审查 Spec** | 跳过 | 可选 | 推荐 | 强烈推荐，可能多轮 |
| **人工 Spec 审查** | 快速确认 | 审查确认 | 基于 AI 报告修订 | 多轮审查，可拉入专家 |
| **Scenario 生成** | AI 生成 | AI 生成 | AI 生成 | AI 生成 |
| **AI 辅助审查 Scenario** | 跳过 | 可选 | 推荐 | 强烈推荐，可能多轮 |
| **人工 Scenario 审查** | 快速扫读 | 审查主流程 + 关键边界 | 审查所有场景，特别是状态转换 | 多轮审查，可拉入专家 |
| **AI 辅助审查 Test** | 跳过 | 可选 | 推荐 | 强烈推荐，可能多轮 |
| **人工 Test 审查** | 跳过 | 可选 | 推荐 | 强烈推荐 |

各级别示例：

- **Trivial**：「把这个函数的参数改成可选」
- **Simple**：「订单列表增加按状态筛选」
- **Medium**：「实现订单退款流程」
- **Complex**：「重构支付系统，支持多币种」

## Epic（史诗）

Epic 不是单一复杂度级别，而是跨多个模块的系统级需求。必须先执行 **Plan（Epic 分解）**，再对每个模块按其自身复杂度独立走 spec-driven-dev 流程。

- **Plan 内容**：模块列表（名称 + 边界 + 上游依赖 + 下游契约 + 复杂度评估）+ 依赖关系图
- **人工 Plan Review**：人确认模块边界合理、依赖关系正确、没有遗漏的集成点
- **示例**：「从零实现移动端 Shell 客户端」、「重构整个支付与计费系统」

---

# Epic 处理：Plan 步骤

当需求为 Epic 时，在进入 spec-driven-dev 流程之前，必须先完成 Plan。

## Plan 的职责

Plan 回答三个问题，**仅此三个**：

1. **What** — 有哪些模块（每个模块的名称和边界）
2. **Order** — 依赖关系（哪些必须串行，哪些可以并行）
3. **Contract** — 模块间接口（上游产出什么，下游消费什么）

Plan **不回答**实现细节（协议格式、API 签名、状态机定义）——这些属于各模块的 Spec。

## Plan 输出格式

每个模块一个条目：

```markdown
## Module: [模块名称]

- **边界**：[这个模块负责构建什么，一句话]
- **模块依赖**：[需要从哪些上游模块消费什么契约，没有则写"无"]
- **产出契约**：[这个模块暴露给下游的接口/能力]
- **复杂度**：[Trivial / Simple / Medium / Complex]
```

加上依赖关系图（文字或 ASCII 表示模块串/并行关系）。

## Plan 的完整流程

```
Epic 需求
  ↓
[Plan 生成]（人描述需求 → AI 生成模块拆解草稿 → 人修订）
  ↓
[Human Plan Review]（确认边界合理、依赖正确、契约完整）
  ↓
按依赖顺序，对每个模块启动独立的 spec-driven-dev 流：
  Module A（Complex）: Spec → Review → Scenario → Review → Tests → Test Review → Impl → CI
  Module B（Medium）:  Spec → Review → Scenario → Tests → Test Review → Impl → CI  ← 依赖 A
  Module C（Simple）:  Spec → Scenario → Tests → Impl → CI                          ← 并行于 B
  ...
```

## Plan Review 检查点

人工审查 Plan 时确认：

- ✅ 每个模块边界清晰、职责单一
- ✅ 没有模块承担了它不该承担的职责（实现细节不在 Plan 里）
- ✅ 依赖关系图完整（没有循环依赖，没有遗漏的集成点）
- ✅ 每个模块的产出契约足够明确，下游可以据此写 Spec
- ✅ 并行路径识别合理（可以并行的没有被串行化）

---

# 迭代修正机制

任何阶段发现问题，允许回退上一步。

## AI 辅助审查 Spec 后发现问题

→ 人根据 AI 审查报告修订 Spec → 可选：再次 AI 辅助审查 → 人确认

## Scenario 生成后发现 Spec 有歧义

→ 标记问题 → 人修订 Spec → 可选：AI 辅助审查 Spec → AI 重新生成 Scenario → 人重新审查

## AI 辅助审查 Scenario 后发现 Spec 遗漏

→ 人修订 Spec → AI 重新生成 Scenario → 可选：AI 辅助审查 Scenario → 人重新审查

## 人工 Scenario 审查发现问题（无 AI 辅助审查时）

→ 人标记问题 → 区分是 Spec 遗漏还是 Scenario 生成问题：
  - Spec 遗漏 → 人修订 Spec → AI 重新生成 Scenario → 人重新审查
  - Scenario 生成问题 → AI 修正 Scenario → 人重新审查

## Test 实现后发现 Scenario 无法自动化

→ 与人确认 → 调整 Scenario 或测试策略 → 重新实现

## Test Review 发现 Scenario → Test 翻译不完整

→ 修复测试断言 → 重新执行 Test Review

## Human Test Review 发现测试策略有问题

→ 人修订测试策略 → AI 重新实现测试 → 重新 Test Review

## Feature 实现后发现 Spec 逻辑矛盾

→ 停止实现 → 人修订 Spec → AI 重新生成 Scenario/Test/Feature

## CI 失败

→ 分析失败原因 → 判断是测试问题还是实现问题 → 修正 → 重新验证

## Spec 编写时发现 Plan 模块边界错误

→ 停止写 Spec → 人修订 Plan（调整模块边界或拆分模块）→ Human Plan Review → 重新编写受影响模块的 Spec

## Test / Feature 实现时发现模块间契约冲突

→ 停止实现 → 确认根因是 Plan 的契约定义有歧义（而非单模块 Spec 问题）→ 人修订 Plan 中相关模块的"产出契约"→ 受影响模块重新走 Spec → Scenario → Test → Feature

**Plan 回退的触发条件须严格限定**，以下情况不应回退 Plan：

- 模块内部实现细节变化（在 Spec 层处理）
- 边界案例补充（在 Scenario 层处理）
- 接口签名调整但语义不变（在 Spec 层处理）

## 关键原则

**Spec 和 Scenario 是人审查的，发现问题必须回退到人审查环节。**

**Plan 是模块边界和契约的唯一真理源**，发现跨模块的边界或契约问题必须回退到 Plan，不允许在 Spec 层悄悄扩展边界。

不允许 AI 自行修改 Spec、Scenario 或 Plan 的语义。

AI 辅助审查只是提供建议，最终决策权在人。

### 跨 Agent 审查原则

所有 AI 辅助审查步骤（Spec Review、Scenario Review、Test Review）均通过 `multi-agent-loop` skill 执行：

- **异构审查**：当前 agent 是 Claude 则启动 Codex 审查，反之亦然，确保独立视角
- **controller 裁决**：审查 agent 只输出结构化发现，controller 逐条裁决，不盲信
- **有界循环**：遵循 `multi-agent-loop` 的循环与终止规则

---

# 工作流

## 步骤 1 — 编写 Spec

人或 AI 创建结构化 markdown 规范，描述系统行为。

推荐章节：

- Feature（功能）
- Goal（目标）
- Rules（规则）
- States（状态，可选）
- State Transitions（状态转换，可选）

> Edge Cases 不在 Spec 里定义——重要的边界规则直接写入 Rules，其余边界案例由 AI 在 Scenario Generation 阶段从 Rules 系统性推导。

示例：

```markdown
# Feature: 订单折扣

## Goal

允许用户在创建订单时应用折扣码。

## Rules

- discount_code 是可选的
- 无效代码返回 INVALID_CODE
- 过期代码返回 EXPIRED_CODE
- 最大折扣为 50%
- 折扣不能超过订单总额
- 折扣不能为负数
```

---

## 步骤 1.5 — AI 辅助审查 Spec（可选）

在 Spec 阶段发现问题，成本最低。**使用 `multi-agent-loop` skill 启动跨 agent 审查**（当前是 Claude 则启动 Codex，反之亦然），确保独立视角。

### 为什么需要 Spec 的 AI 辅助审查？

- **Spec 质量直接影响后续所有步骤**：Spec 有问题，后续全错
- **人容易遗漏细节**：特别是复杂 Spec，容易遗漏边界案例、状态转换、错误处理
- **提前发现问题成本更低**：在 Spec 阶段发现问题，比在实现阶段发现成本低得多

### 何时使用 Spec 的 AI 辅助审查？

根据复杂度决定（见复杂度分级标准）。

### 审查流程

通过 `multi-agent-loop` skill 启动异构 agent 审查。controller 负责编写审查任务（参考 `references/prompt-spec-review.md`），读取审查结果后逐条裁决，展示给人。

### 审查重点

- **完整性**：缺少的规则、状态转换、错误处理（注意：边界案例由 Scenario 阶段推导，不在 Spec 阶段检查）
- **一致性**：术语、逻辑、规则是否有冲突
- **歧义**：模糊描述、未定义行为
- **风险**：安全、性能、可靠性、兼容性

具体审查清单见 `references/prompt-spec-review.md`。

---

## 步骤 1.6 — 人工审查/修订 Spec

人基于 AI 审查报告（如有），审查并修订 Spec。

重点确认：

- Spec 是否完整（目标、规则、已知边界规则都已定义；其余边界案例留给 Scenario 阶段推导）
- Spec 是否清晰（无歧义、无矛盾）
- Spec 是否考虑了风险（安全、性能、可靠性）

修订后，进入下一步。

### Definition of Ready (DoR)

在进入实现阶段前，确认以下条件已满足：

- ✅ 功能目标清晰
- ✅ 业务规则已定义（含已知边界规则）
- ✅ 范围有界
- ✅ 依赖项已知

如不清楚，AI 必须提出澄清问题。

**DoR 是进入步骤 2（生成测试场景）的门禁。**

---

## 步骤 2 — 生成测试场景

主 agent 读取 Spec 并生成人类可读的行为场景。

场景必须以自然语言行为检查的形式编写，并标注测试类型。

首选格式：

```
[TEST_TYPE] 用户执行操作
→ 系统行为

[CRITICAL][TEST_TYPE] 用户执行高风险操作
→ 系统行为
```

示例：

```
[INTEGRATION] 用户创建订单时不提供折扣码
→ 订单正常创建

[CRITICAL][CONTRACT] 用户创建订单时提供过期的折扣码
→ 请求失败，返回 EXPIRED_CODE
```

不要输出测试函数名。

---

## 步骤 2.5 — AI 辅助审查 Scenario（可选）

**使用 `multi-agent-loop` skill 启动跨 agent 审查**。不要让同一个 agent 审查自己刚生成的内容，会陷入相同的思维盲区。

### 何时使用 AI 辅助审查？

根据复杂度决定（见复杂度分级标准）。

### 审查流程

通过 `multi-agent-loop` skill 启动异构 agent 审查。controller 负责编写审查任务（参考 `references/prompt-scenario-review.md`），读取审查结果后逐条裁决，展示给人。

### 审查重点

- **业务覆盖度**：已覆盖 / 可能遗漏的业务规则
- **边界案例**：空值、边界值、权限等
- **失败场景**：已覆盖 / 可能遗漏的失败场景
- **测试类型标记**：每个场景是否标注了合理的测试类型
- **契约风险**：API 契约场景是否标记为 [CRITICAL][CONTRACT]
- **建议补充的场景**（如有）

具体审查清单见 `references/prompt-scenario-review.md`。

---

## 步骤 3 — 人工场景审查

人工审查场景。

如果进行了 AI 辅助审查，人只需要：

1. 阅读 AI 的审查报告
2. 重点关注 AI 标记的 **[CRITICAL]** 场景
3. 确认每个场景的**测试类型标记**合理
4. 做最终确认

如果未进行 AI 辅助审查，人需要重点验证：

- 业务规则已覆盖
- 重要流程存在
- 危险案例存在
- 禁止行为存在
- 场景反映预期行为
- 每个场景的测试类型标记合理

**人工审查行为 + 测试策略，不审查测试代码。**

---

## 步骤 4 — 实现测试

AI 将批准的场景转换为自动化测试。

**前置：建立 Implementation Stub**

在写测试之前，先检查被测模块的实现文件是否存在且 import 路径可解析。如果不存在，必须先创建 Implementation Stub（正确路径 + 正确导出签名 + `throw new Error('not implemented')` 函数体）。**Stub 仅用于避免 import 失败，不计入测试完成度，建立后立即继续写行为测试。**

要求：

- **按场景的测试类型标记（CONTRACT / INTEGRATION / PROPERTY / UNIT）决定测试类型**，不自行判断
- 测试行为而非内部实现
- 避免与私有辅助函数绑定的脆弱测试
- **禁止使用 `skip` / 条件执行代替"实现不存在"**——实现 Stub 后测试必须可运行且为红色
- **禁止以"scaffold 完成"或"stub 已建立"作为交付物**——必须继续完成场景级行为测试

---

## 步骤 4.5 — AI 辅助审查 Test（可选）

**使用 `multi-agent-loop` skill 启动跨 agent 审查**，重点是 **scenario → test 的翻译正确性**（不是代码质量）。

### 何时使用？

根据复杂度决定（见复杂度分级标准）。Trivial/Simple 可跳过，Medium 推荐，Complex 强烈推荐。

### 审查流程

通过 `multi-agent-loop` skill 启动异构 agent。controller 将 scenario 列表和测试文件路径写入审查任务，读取审查结果后逐条裁决。

### 审查重点

1. **全覆盖**：每个 scenario 至少有一个对应的 test
2. **断言完整**：每个 test 的断言覆盖了 scenario 描述的**所有**预期行为（不是只断言了一半）
3. **无越界**：没有 test 在测 scenario 之外的东西（防止 AI 自行发挥）

### Red Run

审查通过后，运行所有测试，确认全部失败且失败原因是 `not implemented`（不是 import 错误、语法错误或其他意外原因）。

- 如果有测试意外通过 → 测试有问题，修复后重新审查
- 如果失败原因不是 `not implemented` → 测试或 stub 有问题，修复后重新运行

---

## 步骤 4.6 — 人工 Test 审查（可选）

人基于 AI 审查报告（如有），审查测试的 **scenario → test 追溯矩阵**。

**人审查的是行为对应关系，不是测试代码。** AI 应输出追溯矩阵供人扫读：

```
| Scenario | Test | 断言摘要 |
|----------|------|---------|
| [CRITICAL][CONTRACT] 过期折扣码 → EXPIRED_CODE | test_expired_code | ✅ error=EXPIRED_CODE ✅ 库存不变 |
| [INTEGRATION] 无折扣码 → 正常创建 | test_no_discount | ✅ 订单创建 ⚠️ 未断言金额 |
```

何时使用：根据复杂度决定（见复杂度分级标准）。

---

## 步骤 5 — 实现功能

### 5.1 Baseline Test Run（前置）

在写任何实现代码之前，运行当前 Spec 范围内的全部测试，记录 baseline 失败列表。区分：

- **属于当前 Spec 范围的失败** → 必须通过实现消除，不得归为"预存在问题"
- **不属于当前 Spec 范围的失败** → 记录为预存在问题，不负责

### 5.2 实现

AI 在以下约束下实现功能：

- 遵循 Spec
- 实现当前 Spec 范围内的所有功能域（测试验证由步骤 6 CI 验证负责）
- 保持最小范围
- 避免无关重构
- 除非明确更改，否则保留外部契约

### 5.3 Spec 完整性校验（实现完成后）

逐条对照 Spec 中定义的所有功能域/服务/组件，确认每个都有生产级实现（不是 stub）。输出完整性矩阵（见 `references/prompt-feature-implementation.md`）。

如有功能域因客观原因无法实现，必须向人工报告并获得确认，不得自行跳过。

---

## 步骤 6 — CI 验证

功能完成需要通过检查。

### 6.1 Baseline 对比

运行仓库全量测试，对比步骤 5.1 记录的 baseline：

- baseline 中属于当前 Spec 范围的失败必须全部消除
- 不得出现新增失败

### 6.2 最低检查

- lint
- typecheck
- tests（含 6.1 的 baseline 对比）
- CI pipeline

### 6.3 可选检查

- contract validation
- snapshot validation
- benchmark checks
- migration safety

### Definition of Done (DoD)

任务完成的标准：

- ✅ Spec 存在或已更新
- ✅ 场景已生成并审查
- ✅ 测试已实现（Step 4 产物；通过验证由 CI 验证负责）
- ✅ Test Review 已完成（如适用：跨 agent 对照审查 + Red Run + 追溯矩阵）
- ✅ Spec 中定义的所有功能域/服务均已实现（不存在 stub 或未实现的模块）
- ✅ Spec 完整性矩阵已输出（AI 自检；若存在 ❌ 项则须人工确认）
- ✅ CI 验证通过（含 baseline 对比：当前 Spec 范围内失败已全部消除，无新增失败）
- ✅ 避免无关重构
- ✅ 现有行为未被静默破坏

可选：

- 文档已更新
- changelog 已更新
- 迁移计划已记录

**DoD 是整个任务完成的检查清单。**

---

# 场景格式

使用人类可读的行为描述，每个场景必须标注测试类型。

首选格式：

```
[TEST_TYPE] 用户执行操作
→ 系统行为

[CRITICAL][TEST_TYPE] 用户执行高风险操作
→ 系统行为
```

示例：

```
[INTEGRATION] 用户创建未付款订单
→ 订单状态变为 CREATED

[INTEGRATION] 用户支付现有订单
→ 订单状态变为 PAID

[CRITICAL][INTEGRATION] 用户取消已发货订单
→ 取消失败
```

避免审查原始测试名称，例如：

```
test_cancel_shipped_order_should_fail
```

## 场景标记

AI 生成场景时，每个场景必须标注 **测试类型** + 可选的 **[CRITICAL]**。

### 测试类型标记

| 标记 | 适用场景 |
|------|---------|
| `[CONTRACT]` | API 响应结构、错误码、对外承诺 |
| `[INTEGRATION]` | 端到端业务流程 |
| `[PROPERTY]` | 不变量（任意输入下成立的规则）|
| `[UNIT]` | 单一函数/规则的孤立验证 |

优先级：**CONTRACT > INTEGRATION > PROPERTY > UNIT**

### 关键测试标记

高风险场景额外加 `[CRITICAL]`：

```
[CRITICAL][CONTRACT] 用户尝试使用过期折扣码
→ 请求失败，返回 EXPIRED_CODE，不扣减库存

[CRITICAL][INTEGRATION] 管理员删除有关联订单的用户
→ 删除失败，保护数据完整性

[PROPERTY] 折扣金额不超过订单总额
→ 任意输入下此不变量成立

[INTEGRATION] 用户查看订单列表
→ 返回按创建时间倒序的订单
```

`[CRITICAL]` 判断标准：

1. **Contract（契约）**：涉及 API 响应结构、错误码、对外承诺
2. **Money（金钱）**：涉及支付、退款、折扣计算
3. **Permission（权限）**：涉及访问控制、数据安全
4. **State Transition（状态转换）**：涉及关键业务状态变化
5. **Data Integrity（数据完整性）**：涉及数据一致性、关联完整性

人工审查时，**优先关注标记为 [CRITICAL] 的场景**。

---

# 测试什么

按此顺序优先测试：

1. 契约稳定性
2. 主要业务流程
3. 关键业务规则
4. 危险边界案例
5. 不变量/属性

---

## 契约测试

保护 API 和模式稳定性。

示例：

- API 响应字段
- 事件负载结构
- 错误代码
- 权限行为

---

## 集成测试

验证端到端工作流。

示例：

- 创建订单
- 支付订单
- 取消订单
- 退款订单

---

## 属性测试

验证不变量。

示例：

- 订单总额永远不能为负
- 库存永远不能为负
- 订单不能有两个最终状态

---

# 不要过度测试什么

避免过度测试：

- 私有辅助函数
- 内部实现细节
- 琐碎逻辑
- 脆弱的快照
- 重复案例

只有在保护行为时，高覆盖率才有价值。

---

# 提示模板

所有提示模板已移至 `references/` 目录，方便维护和复用：

- [AI 辅助审查 Spec](./references/prompt-spec-review.md) - 跨 agent 审查 Spec 的提示词
- [场景生成](./references/prompt-scenario-generation.md) - 从 Spec 生成测试场景的提示词
- [AI 辅助审查场景](./references/prompt-scenario-review.md) - 跨 agent 审查场景的提示词
- [AI 辅助审查 Test](./references/prompt-test-review.md) - 跨 agent 审查 scenario → test 翻译正确性的提示词
- [测试实现](./references/prompt-test-implementation.md) - 根据场景实现测试的提示词
- [功能实现](./references/prompt-feature-implementation.md) - 根据 Spec 和测试实现功能的提示词
- [测试扩展](./references/prompt-test-expansion.md) - 建议额外高价值测试场景的提示词（备用模板，未接入主流程，按需手动调用）

---

# 推荐仓库结构

```
spec/
tests/
src/
```

可选结构（monorepo）：

```
spec/
  feature.md

apps/my-app/                    ← workspace
  src/
    services/
      UserService.ts
      UserService.test.ts       ← UNIT + PROPERTY，colocate
  tests/
    contract/                   ← CONTRACT，子目录镜像 src/
    integration/                ← INTEGRATION，子目录镜像 src/

libs/my-lib/                    ← 另一个 workspace
  src/
    AuthToken.ts
    AuthToken.test.ts           ← UNIT + PROPERTY，colocate
  tests/
    contract/
    integration/
```

**归属原则：测试先归属 workspace，再按类型分目录。禁止跨 workspace 在仓库根聚合测试。**

测试优先级：

**contract > integration > property > unit**

---

# 最终规则

永远不允许 AI 从模糊请求直接跳到代码。

**判断入口**：收到开发需求时，首先判断是 Epic 还是单模块：

- 需求跨多个模块、有明确模块间依赖 → **Epic**，必须先走 Plan
- 需求范围清晰、单模块可承载 → **直接走 Spec 层**

**Epic 流程**：

```
Plan（模块拆解 + 依赖图 + 契约）
→ Human Plan Review
→ 对每个模块独立执行 Spec 层流程（按依赖顺序，可并行）
```

**Spec 层流程**（每个模块）：

```
Spec
→ AI-Assisted Spec Review (可选，multi-agent-loop 跨 agent 审查)
→ Human Spec Review
→ Scenario Generation
→ AI-Assisted Scenario Review (可选，multi-agent-loop 跨 agent 审查)
→ Human Scenario Review
→ Test Implementation
→ AI-Assisted Test Review (可选，multi-agent-loop 跨 agent 对照审查 + Red Run)
→ Human Test Review (可选，审查追溯矩阵)
→ Feature Implementation
→ CI Verification
```
