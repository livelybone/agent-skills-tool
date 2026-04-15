# 标准模式工作流详细步骤

> **进度检查点**：每个步骤完成后，必须立即更新 `spec/<module>.md` frontmatter 的进度状态（Epic 模式同时更新 `plan.md` Progress 表）。详见 SKILL.md > 进度检查点。
>
> **Context 压力处理**：context 接近上限时，写检查点 → 压缩上下文 → 继续执行，不得中断。详见 SKILL.md > Context 压力处理。

## 步骤 0 — 建模（始终执行，豁免需记录理由）

调用 `modeling-first` skill 产出或增量更新建模文件。此步骤是流程内硬步骤，不可跳过（除非符合豁免条件）。

### 全量建模

目标模块尚无 `model.md` → 调用 `modeling-first` 完整模式，从零产出 `<module>/model.md`。

### 增量建模

目标模块已有 `model.md` 且本次变更引入新的领域信息（新实体/关系/不变量/派生关系/状态变化逻辑）→ 调用 `modeling-first`，在现有 `model.md` 上增量更新。

增量建模约束：
- **必须通过 `modeling-first` 执行**，不得绕过 skill 直接手编 `model.md`
- 更新后 `model.md` 必须整体满足 `modeling-first` 质量门槛
- 已有锚点不得删除或重命名（除非下游 `upstream-ref` 同步更新）
- 更新后重新验证（反向、派生、复用、最小性、可引用）

### 豁免

本次变更符合 `modeling-first` SKILL.md Step 1 "不需要建模"清单 → 在 DoR 中记录豁免理由，跳过此步骤。

### 审查

- 标准模式：人工审查建模产物
- Auto 模式：跨 agent 审查（见 SKILL.md > 跨 Agent 审查原则，prompt 模板见 `prompts/upstream-review.md`）

---

## 步骤 1 — Spec 生成

Spec 的主导方取决于复杂度分级（见 `guides/complexity.md`）。**必须基于 `templates/spec.md` 模板**，包含 YAML frontmatter 进度检查点。

必填章节：

- Feature（功能）
- Goal（目标）
- Rules（规则，每条带 upstream-ref）

可选章节：

- States（状态，涉及状态机时）
- State Transitions（状态转换，涉及状态机时）
- 非功能约束（有明确非功能需求时）

> Edge Cases 不在 Spec 里定义——重要的边界规则直接写入 Rules，其余边界案例由 AI 在 Scenario Generation 阶段从 Rules 系统性推导。

Spec 文件必须包含 YAML frontmatter 用于进度追踪（初始状态）：

```markdown
---
module: order-discount
current_step: 1
current_step_name: Spec 生成
status: in_progress
last_completed_step: 0
last_completed_step_name: 建模
context_summary: ""
decision_log_ref: ""
updated: 2026-04-14T08:00
---

# Feature: 订单折扣

## Goal

允许用户在创建订单时应用折扣码。

## Rules

- discount_code 是可选的（upstream-ref: model.md#Entity.Order）
- 无效代码返回 INVALID_CODE（upstream-ref: model.md#Invariant.Discount.1）
- 过期代码返回 EXPIRED_CODE（upstream-ref: model.md#Invariant.Discount.2）
- 最大折扣为 50%（upstream-ref: model.md#Invariant.Discount.3）
- 折扣不能超过订单总额（upstream-ref: model.md#Derivation.Order.discountedTotal）
- 折扣不能为负数（upstream-ref: model.md#Invariant.Discount.4）
```

每个步骤完成后更新 frontmatter 的 `current_step`、`status`、`context_summary` 等字段。

---

## 步骤 2 — 跨 agent 审查 Spec（可选）

按复杂度决定是否执行（见 `guides/complexity.md`）。审查机制见 SKILL.md > 跨 Agent 审查原则，审查任务参考 `prompts/spec-review.md`。

### 审查重点

- **完整性**：缺少的规则、状态转换、错误处理（边界案例由 Scenario 阶段推导）
- **一致性**：术语、逻辑、规则是否有冲突
- **歧义**：模糊描述、未定义行为
- **风险**：安全、性能、可靠性、兼容性

---

## 步骤 3 — 人工审查/修订 Spec

人基于 AI 审查报告（如有），审查并修订 Spec。

重点确认：

- Spec 是否完整（目标、规则、已知边界规则都已定义）
- Spec 是否清晰（无歧义、无矛盾）
- Spec 是否考虑了风险（安全、性能、可靠性）

修订后，进入下一步。DoR 校验见 SKILL.md。

---

## 步骤 4 — 生成测试场景

主 agent 读取 Spec 并生成人类可读的行为场景。格式详见 `guides/scenario-format.md`，生成提示词参考 `prompts/scenario-generation.md`。

---

## 步骤 5 — 跨 agent 审查 Scenario（可选）

按复杂度决定是否执行（见 `guides/complexity.md`）。审查机制见 SKILL.md > 跨 Agent 审查原则，审查任务参考 `prompts/scenario-review.md`。

### 审查重点

- **业务覆盖度**：已覆盖 / 可能遗漏的业务规则
- **边界案例**：空值、边界值、权限等
- **失败场景**：已覆盖 / 可能遗漏的失败场景
- **测试类型标记**：每个场景是否标注了合理的测试类型
- **契约风险**：API 契约场景是否标记为 [CRITICAL][CONTRACT]

---

## 步骤 6 — 人工场景审查

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

## 步骤 7 — 实现测试

AI 将批准的场景转换为自动化测试。详细实现指南见 `prompts/test-implementation.md`，测试策略（测什么/不测什么/Stub 规则/禁止事项）见 `guides/testing.md`，测试文件位置见 `guides/repo-structure.md`。

---

## 步骤 8 — 跨 agent 审查 Test（可选）

Trivial/Simple 可跳过，Medium 推荐，Complex 强烈推荐。审查机制见 SKILL.md > 跨 Agent 审查原则，审查任务参考 `prompts/test-review.md`。

重点是 **scenario → test 的翻译正确性**（不是代码质量）。

### 审查重点

1. **全覆盖**：每个 scenario 至少有一个对应的 test
2. **断言完整**：每个 test 的断言覆盖了 scenario 描述的**所有**预期行为
3. **无越界**：没有 test 在测 scenario 之外的东西

---

## 步骤 8.5 — Red Run（始终执行）

详细协议见 `guides/testing.md` > Red Run 协议。Standard 和 Auto 模式均适用。

---

## 步骤 9 — 人工 Test 审查（可选）

人审查测试的 **scenario → test 追溯矩阵**（行为对应关系，不是测试代码）：

```
| Scenario | Test | 断言摘要 |
|----------|------|---------|
| [CRITICAL][CONTRACT] 过期折扣码 → EXPIRED_CODE | test_expired_code | ✅ error=EXPIRED_CODE ✅ 库存不变 |
| [INTEGRATION] 无折扣码 → 正常创建 | test_no_discount | ✅ 订单创建 ⚠️ 未断言金额 |
```

---

## 步骤 10 — 实现功能

### 10.1 Baseline Test Run（前置）

运行当前 Spec 范围内的全部测试，记录 baseline 失败列表：
- **属于当前 Spec 范围的失败** → 必须通过实现消除
- **不属于当前 Spec 范围的失败** → 记录为预存在问题

### 10.2 实现

AI 在以下约束下实现功能：
- 遵循 Spec
- 实现当前 Spec 范围内的所有功能域
- 保持最小范围
- 避免无关重构
- 除非明确更改，否则保留外部契约

### 10.3 Spec 完整性校验（实现完成后）

逐条对照 Spec 中定义的所有功能域/服务/组件，确认每个都有生产级实现（不是 stub）。输出完整性矩阵（见 `prompts/feature-implementation.md`）。

如有功能域因客观原因无法实现，必须向人工报告并获得确认，不得自行跳过。

---

## 步骤 11 — CI 验证

### 11.1 Baseline 对比

运行仓库全量测试，对比步骤 10.1 记录的 baseline：
- baseline 中属于当前 Spec 范围的失败必须全部消除
- 不得出现新增失败

### 11.2 最低检查

- lint
- typecheck
- tests（含 baseline 对比）
- **coverage gate**（覆盖率阈值检查，见 `test-quality-gate` skill）
- **mutation score gate**（变异测试阈值检查，见 `test-quality-gate` skill）
- **upstream coverage gate**（建模追溯机械校验）：执行 `skills/spec-driven-dev/scripts/check-upstream-coverage.sh`，传入 `--upstream <model.md|epic-model.md>`（basename 必须是这两个之一，与 `modeling-first` 硬耦合）、`--matrix <Upstream Coverage Matrix>`、`--refs-glob <测试/场景/Spec 文件 glob>`。脚本失败即 CI 失败。若本阶段明确"无需建模"（记录在 DoR 的理由中），跳过本项并在 CI 日志中显式注明
- CI pipeline

> coverage gate 和 mutation score gate 的具体配置、阈值策略、打回修复流程由 `test-quality-gate` skill 提供。若项目尚未配置这两项 CI，在 CI Verification 步骤触发 `test-quality-gate` 的配置补全流程。

### 11.3 code-review 结构质量检查

按复杂度决定是否执行（见 `guides/complexity.md`）。

调用 `code-review` skill，`--scope=diff`，检测实现引入的克隆、意图级重复、设计质量问题。

**与 upstream coverage gate 的分工**：`code-review` 的"建模对齐检查"中，ref 存在性验证（`upstream-ref` 指向的文件/行号是否真实存在）由 upstream coverage gate（11.2）覆盖，在本流程中跳过；语义对齐验证（实现是否偏离 `model.md` 声明的实体/关系/不变量语义）仍由 `code-review` 执行。

**门槛与修复闭环**：

- **HIGH 级问题**：必须修复。修复后重跑 11.2，确认未引入回归，然后重跑 code-review 确认 HIGH 已消除
- **MEDIUM 级问题**：记录到 PR 描述或 Decision Log（Auto 模式），由人决定是否修复，不阻塞流程
- **LOW 级问题**：记录即可

> **修复范围约束**：修复 code-review 发现的问题时，仅限于消除检出的重复/冗余，不得借机做超出 Spec 范围的重构。若修复不可避免地涉及 Spec 外代码，记录影响范围并升级给人工确认。

### 11.4 可选检查

- contract validation
- snapshot validation
- benchmark checks
- migration safety
