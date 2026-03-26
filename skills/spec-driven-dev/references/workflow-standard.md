# 标准模式工作流详细步骤

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

## 步骤 1.5 — 跨 agent 审查 Spec（可选）

按复杂度决定是否执行（见 complexity-guide.md）。审查机制见 SKILL.md > 跨 Agent 审查原则，审查任务参考 `prompt-spec-review.md`。

### 审查重点

- **完整性**：缺少的规则、状态转换、错误处理（边界案例由 Scenario 阶段推导）
- **一致性**：术语、逻辑、规则是否有冲突
- **歧义**：模糊描述、未定义行为
- **风险**：安全、性能、可靠性、兼容性

---

## 步骤 1.6 — 人工审查/修订 Spec

人基于 AI 审查报告（如有），审查并修订 Spec。

重点确认：

- Spec 是否完整（目标、规则、已知边界规则都已定义）
- Spec 是否清晰（无歧义、无矛盾）
- Spec 是否考虑了风险（安全、性能、可靠性）

修订后，进入下一步。DoR 校验见 SKILL.md。

---

## 步骤 2 — 生成测试场景

主 agent 读取 Spec 并生成人类可读的行为场景。格式详见 scenario-format.md。

---

## 步骤 2.5 — 跨 agent 审查 Scenario（可选）

按复杂度决定是否执行（见 complexity-guide.md）。审查机制见 SKILL.md > 跨 Agent 审查原则，审查任务参考 `prompt-scenario-review.md`。

### 审查重点

- **业务覆盖度**：已覆盖 / 可能遗漏的业务规则
- **边界案例**：空值、边界值、权限等
- **失败场景**：已覆盖 / 可能遗漏的失败场景
- **测试类型标记**：每个场景是否标注了合理的测试类型
- **契约风险**：API 契约场景是否标记为 [CRITICAL][CONTRACT]

---

## 步骤 3 — 人工场景审查

如果进行了 跨 agent 审查，人只需要：
1. 阅读 AI 的审查报告
2. 重点关注 AI 标记的 **[CRITICAL]** 场景
3. 确认每个场景的**测试类型标记**合理
4. 做最终确认

如果未进行 跨 agent 审查，人需要重点验证：
- 业务规则已覆盖
- 重要流程存在
- 危险案例存在
- 禁止行为存在
- 每个场景的测试类型标记合理

**人工审查行为 + 测试策略，不审查测试代码。**

---

## 步骤 4 — 实现测试

AI 将批准的场景转换为自动化测试。

**前置：建立 Implementation Stub**

在写测试之前，先检查被测模块的实现文件是否存在且 import 路径可解析。如果不存在，必须先创建 Implementation Stub（正确路径 + 正确导出签名 + `throw new Error('not implemented')` 函数体）。**Stub 仅用于避免 import 失败，不计入测试完成度。**

要求：

- **按场景的测试类型标记（CONTRACT / INTEGRATION / PROPERTY / UNIT）决定测试类型**，不自行判断
- 测试行为而非内部实现
- 避免与私有辅助函数绑定的脆弱测试
- **禁止使用 `skip` / 条件执行代替"实现不存在"**——Stub 后测试必须可运行且为红色
- **禁止以"scaffold 完成"或"stub 已建立"作为交付物**——必须继续完成场景级行为测试

---

## 步骤 4.5 — 跨 agent 审查 Test（可选）

Trivial/Simple 可跳过，Medium 推荐，Complex 强烈推荐。审查机制见 SKILL.md > 跨 Agent 审查原则，审查任务参考 `prompt-test-review.md`。

重点是 **scenario → test 的翻译正确性**（不是代码质量）。

### 审查重点

1. **全覆盖**：每个 scenario 至少有一个对应的 test
2. **断言完整**：每个 test 的断言覆盖了 scenario 描述的**所有**预期行为
3. **无越界**：没有 test 在测 scenario 之外的东西

---

## 步骤 4.55 — Red Run（始终执行）

**无论是否执行了跨 agent 审查 Test，Red Run 都必须执行。**

### 作用域

Red Run **只运行当前 Spec 范围内新增/修改的测试**，不运行仓库全量测试（全量测试由步骤 6 CI 验证负责）。

- 新项目（无存量代码）：所有测试即为当前 Spec 范围内的测试
- 增量开发（有存量代码）：只运行本轮步骤 4 新增的测试文件/测试用例

### 预期结果

当前 Spec 范围内的测试全部失败，且失败原因符合预期：

- **新建 Stub 的模块**：失败原因应为 `not implemented`
- **已有实现的模块（增量开发）**：失败原因应为功能未实现或行为不符合新 Spec（具体原因因场景而异）

### 异常处理

- 测试意外通过 → 测试有问题（断言不充分），修复后重新运行
- 失败原因是 import 错误、语法错误等非业务原因 → 测试或 stub 有问题，修复后重新运行

---

## 步骤 4.6 — 人工 Test 审查（可选）

人审查测试的 **scenario → test 追溯矩阵**（行为对应关系，不是测试代码）：

```
| Scenario | Test | 断言摘要 |
|----------|------|---------|
| [CRITICAL][CONTRACT] 过期折扣码 → EXPIRED_CODE | test_expired_code | ✅ error=EXPIRED_CODE ✅ 库存不变 |
| [INTEGRATION] 无折扣码 → 正常创建 | test_no_discount | ✅ 订单创建 ⚠️ 未断言金额 |
```

---

## 步骤 5 — 实现功能

### 5.1 Baseline Test Run（前置）

运行当前 Spec 范围内的全部测试，记录 baseline 失败列表：
- **属于当前 Spec 范围的失败** → 必须通过实现消除
- **不属于当前 Spec 范围的失败** → 记录为预存在问题

### 5.2 实现

AI 在以下约束下实现功能：
- 遵循 Spec
- 实现当前 Spec 范围内的所有功能域
- 保持最小范围
- 避免无关重构
- 除非明确更改，否则保留外部契约

### 5.3 Spec 完整性校验（实现完成后）

逐条对照 Spec 中定义的所有功能域/服务/组件，确认每个都有生产级实现（不是 stub）。输出完整性矩阵（见 `prompt-feature-implementation.md`）。

如有功能域因客观原因无法实现，必须向人工报告并获得确认，不得自行跳过。

---

## 步骤 6 — CI 验证

### 6.1 Baseline 对比

运行仓库全量测试，对比步骤 5.1 记录的 baseline：
- baseline 中属于当前 Spec 范围的失败必须全部消除
- 不得出现新增失败

### 6.2 最低检查

- lint
- typecheck
- tests（含 baseline 对比）
- CI pipeline

### 6.3 可选检查

- contract validation
- snapshot validation
- benchmark checks
- migration safety
