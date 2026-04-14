---
module: <module-name>
current_step: 1
current_step_name: Spec 生成
status: in_progress
last_completed_step: 0
last_completed_step_name: 建模
context_summary: ""
decision_log_ref: ""
updated: <ISO-timestamp>
---

# Feature: <Feature Name>

> 📖 **填写前必读**：
> - 本模块的 `model.md`（建模文件，步骤 0 产出）
> - `workflows/standard.md#步骤1`（Spec 编写规则）
> - `guides/scenario-format.md`（Scenario 格式，步骤 4 时需要）

**Goal**: <一句话：这个模块要实现什么>
**Source**: <需求来源：Spec 原始需求 / Plan 中的模块边界描述 / issue 链接>
**Upstream Model**: <建模文件路径，如 `docs/models/order/model.md`>

---

## Rules

业务规则。每条规则末尾标注 upstream-ref，指向建模文件中的锚点。

- <规则描述>（upstream-ref: model.md#Invariant.Entity.N）
- <规则描述>（upstream-ref: model.md#Derivation.Entity.field）
- <规则描述>（upstream-ref: N/A + 纯业务流程规则，无对应建模条目）

> **重要**：Edge Cases 不在 Rules 里穷举——重要的边界规则直接写入 Rules，其余边界案例由 AI 在 Scenario Generation 阶段从 Rules 系统性推导。

---

## States（可选）

状态枚举。仅当模块涉及状态机时填写。

- `<state1>` — <描述>（upstream-ref: model.md#Invariant.Entity.N）
- `<state2>` — <描述>（upstream-ref: model.md#Entity.EntityName）

---

## State Transitions（可选）

状态转换规则。仅当模块涉及状态机时填写。

- `<state1>` → `<state2>` — 触发条件：<描述>（upstream-ref: model.md#Invariant.Entity.N）
- 禁止：`<stateA>` → `<stateB>` — 原因：<描述>（upstream-ref: N/A + 纯安全约束，无对应建模条目）

---

## 非功能约束（可选）

性能、安全、合规等约束。仅当有明确非功能需求时填写。

- <约束描述>

---

## Frontmatter 字段说明（生成后删除此节）

| 字段 | 说明 | 更新时机 |
|------|------|---------|
| `module` | 模块名，与文件名一致 | 创建时 |
| `current_step` | 当前步骤编号（见下方对照表） | 每步完成后 |
| `current_step_name` | 当前步骤名称 | 每步完成后 |
| `status` | `pending` / `in_progress` / `done` / `blocked:<原因>` | 每步完成后 |
| `last_completed_step` | 最后完成的步骤编号 | 每步完成后 |
| `last_completed_step_name` | 最后完成的步骤名称 | 每步完成后 |
| `context_summary` | 关键上下文摘要（审查结论、裁决数、已知问题） | 每步完成后 |
| `decision_log_ref` | Decision Log 临时文件路径（Auto 模式） | 首次写入 Decision Log 时 |
| `updated` | ISO 时间戳 | 每次更新 frontmatter 时 |

**步骤编号对照**（与 SKILL.md Spec 层流程一致）：

| 编号 | 标准模式 | Auto 模式 |
|------|---------|----------|
| 0 | 建模 | 建模 + AI 审查建模 |
| 1 | Spec 生成 | Spec 生成 |
| 2 | 跨 agent 审查 Spec（可选） | AI 跨 agent 审查 Spec（强制） |
| 3 | 人工 Spec 审查 + DoR 校验 | DoR 校验 |
| 4 | Scenario 生成 | Scenario 生成 |
| 5 | 跨 agent 审查 Scenario（可选） | AI 跨 agent 审查 Scenario（强制） |
| 6 | 人工 Scenario 审查 | —（Auto 无此步） |
| 7 | Test Implementation | Test Implementation |
| 8 | 跨 agent 审查 Test（可选） | AI 跨 agent 审查 Test（强制） |
| 8.5 | Red Run | Red Run |
| 9 | 人工 Test 审查（可选） | Baseline Test Run |
| 10 | Feature Implementation | Feature Implementation |
| 11 | CI Verification | Spec 完整性校验 |
| — | — | 12 CI Verification（Auto） |
| — | — | 13 输出 Decision Report（Auto 专有） |

> 本节仅供参考，Spec 正式产出后应删除。
