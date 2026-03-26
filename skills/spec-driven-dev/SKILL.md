---
name: spec-driven-dev
description: 强制执行规范驱动的 AI 开发工作流。Epic 级需求先 Plan（模块拆解 + 依赖图 + 契约定义），再对每个模块独立走 Spec → Scenarios → Tests → Implementation → CI 流程。支持 Auto 模式（--auto）：全流程自动化，AI 审查裁决，结束后输出 Decision Report。触发词：spec、plan、epic、模块拆解、开发规范、需求拆分、--auto。
metadata:
  version: 2.0
  tags:
    - ai-workflow
    - spec-driven
    - epic-planning
    - testing
    - development-process
---

# 规范驱动开发 Skill

## 核心原则

- Spec 是唯一的真理源
- 人类定义行为；AI 执行（Auto 模式下 AI 代行审查并记录裁决）
- 测试场景是人类可读的；测试代码由 AI 生成
- 实现必须满足测试；CI 是最终强制层
- 优先行为验证而非实现测试
- 优先少量高价值测试而非大量脆弱测试套件

---

## 人机分工

**人**：定义/审查行为（Spec + Scenario），不管代码
**AI**：执行（生成 Scenario、写 Test、写 Feature、建议遗漏的边界案例、暴露 Spec 歧义）
**测试**：保证 AI 生成的代码符合人审查的场景

**Auto 模式下**：人只提出需求 → 流程结束后审阅 Decision Report → 对 High / Medium Risk 裁决做事后复核

---

## 入口判断

收到开发需求时，判断两个维度：

**1. 模式**：是否指定 `--auto`？

- 指定 → **Auto 模式**（全自动，AI 裁决，流程结束输出 Decision Report）
- 未指定 → **标准模式**（需人工审查）
- **中途切换**：标准模式执行中用户可随时指定 `--auto` 切换为 Auto 模式，从当前步骤开始自动推进（见下方"中途切换 Auto 模式"）

**2. 规模**：Epic 还是单模块？

- 需求跨多个模块、有明确模块间依赖 → **Epic**，必须先走 Plan
- 需求范围清晰、单模块可承载 → **直接走 Spec 层**

永远不允许 AI 从模糊请求直接跳到代码。

---

## 标准模式流程

### Epic 流程

```
Plan（模块拆解 + 依赖图 + 契约）→ 详见 references/workflow-epic.md
→ Human Plan Review
→ 对每个模块独立执行 Spec 层流程（按依赖顺序，可并行）
```

### Spec 层流程（每个模块）

```
1. Spec 生成                                → 详见 references/workflow-standard.md#步骤1
2. 跨 agent 审查 Spec（按复杂度可选）          → 详见 references/workflow-standard.md#步骤1.5
3. 人工 Spec 审查 + DoR 校验                 → 详见 references/workflow-standard.md#步骤1.6
4. Scenario 生成                             → 详见 references/scenario-format.md
5. 跨 agent 审查 Scenario（按复杂度可选）       → 详见 references/workflow-standard.md#步骤2.5
6. 人工 Scenario 审查
7. Test Implementation（含 Stub）              → 详见 references/workflow-standard.md#步骤4
8. 跨 agent 审查 Test（按复杂度可选）           → 详见 references/workflow-standard.md#步骤4.5
8.5 Red Run（始终执行）                        → 详见 references/workflow-standard.md#步骤4.55
9. 人工 Test 审查（按复杂度可选）
10. Feature Implementation（含 Baseline）      → 详见 references/workflow-standard.md#步骤5
11. CI Verification                           → 详见 references/workflow-standard.md#步骤6
```

步骤 7、8.5、10、11 始终执行。其余步骤按复杂度调整深度（详见 references/complexity-guide.md）。

---

## Auto 模式流程

Auto 模式保留标准模式的**所有执行步骤**，仅将 Human Review 替换为 AI 跨 agent 审查 + AI 裁决。

**禁止中断**：除裁决升级条件外，不得以任何理由暂停流程。
**禁止简化审查**：每个模块的每个审查步骤必须完整执行跨 agent 审查，不得因"改动小"、"上下文长"等理由降级。
**Subagent 不替代流程**：subagent 只执行单步任务，不得将多个流程步骤打包；每步必须产出阶段性产物（Spec/Scenario 文件、Decision Log 等），缺产物禁止推进。
**步骤严格串行**：单个模块内的步骤 1→2→…→13 必须顺序执行，不得并行。原因：每个审查步骤可能触发回退修正，后续步骤依赖前置步骤的审查结果。
详细规则见 `references/workflow-auto.md`。

### Spec 层流程（每个模块）

```
1. Spec 生成（AI 生成）
2. AI 跨 agent 审查 Spec（强制）→ AI 裁决 → Decision Log
3. DoR 校验（AI 自检，不满足则升级给用户）
4. Scenario 生成
5. AI 跨 agent 审查 Scenario（强制）→ AI 裁决 → Decision Log
6. Test Implementation（含 Implementation Stub）
7. AI 跨 agent 审查 Test（强制）→ AI 裁决 → Decision Log
8. Red Run（审查通过后执行，确认全部红色）
9. Baseline Test Run（记录当前失败列表）
10. Feature Implementation
11. Spec 完整性校验（有 ❌ 项则升级给用户）
12. CI Verification（含 Baseline 对比）
13. 输出 Decision Report
```

### Epic 流程

```
Plan 生成 → AI 跨 agent 审查 Plan → AI 裁决 → Decision Log
→ 对每个模块独立执行上方 Auto Spec 层流程
→ 输出汇总 Decision Report（Plan 级 + 各模块级）
```

---

## 中途切换 Auto 模式

标准模式执行中，用户可随时指定 `--auto` 切换为 Auto 模式。

切换规则：

- **已完成的步骤保留**：人工已审查的 Spec/Scenario 不需要重新走 AI 审查
- **当前步骤起切换**：从用户指定 `--auto` 时的下一个未完成步骤开始，按 Auto 模式规则执行
- **Decision Log 从切换点开始记录**：切换前的人工审查不纳入 Decision Log
- **Decision Report 标注切换点**：报告开头注明"从步骤 N 起切换为 Auto 模式"，以及切换前已由人工完成的步骤清单

示例：

```
用户：Spec 我已经审查通过了，后面 --auto 帮我走完
→ 从步骤 4（Scenario 生成）开始自动执行
→ 步骤 1-3 标记为"人工已完成"，步骤 4-13 按 Auto 模式规则执行
```

---

## 迭代修正机制

任何阶段发现问题，允许回退上一步。详细回退规则见 `references/iteration-rules.md`。

**关键原则**：

**标准模式**：

- Spec 和 Scenario 是人审查的，发现问题必须回退到人审查环节
- Plan 是模块边界和契约的唯一真理源，不允许在 Spec 层悄悄扩展边界
- 不允许 AI 自行修改 Spec、Scenario 或 Plan 的语义

**Auto 模式例外**：

- AI 可在裁决权限范围内修改 Spec/Scenario/Plan，但每次必须记录 Decision Log（含变更前后对照）
- 超出裁决权限的修改仍必须升级给用户

### 跨 Agent 审查原则

本文档中所有"跨 agent 审查"均指：**使用 `multi-agent-loop` skill 启动一个独立的审查进程**。优先选择与当前 coding agent 不同的 agent（如当前是 Claude 则启动 Codex/OpenCode），以获得独立视角。若环境中不存在其他可用的 coding agent，允许使用同一 agent 但必须通过 `multi-agent-loop` 启动独立进程，确保审查上下文与执行上下文隔离。

执行要点：

- **优先异构**：审查 agent 优先选择与当前执行 agent 不同的 agent；无可用异构 agent 时，使用同一 agent 的独立进程
- **controller 裁决**：审查 agent 只输出结构化发现，controller（当前 agent）逐条裁决，不盲信
- **有界循环**：每次审查必须遵循 `multi-agent-loop` 的完整循环规则：
  - **裁决时重新评估严重度**：agent 的严重度标注仅供参考，controller 必须对每条发现独立判断实际严重度。后期轮次 agent 倾向于严重度膨胀（将 Minor 级问题标为 Major 以维持"仍有重要发现"的表象），controller 不得盲信。
  - **继续条件**：经 controller 重新评估后，本轮存在至少一条被裁决为 Major 及以上的发现（无论是否已修复）→ 修复后**必须**启动下一轮，由新 agent 独立审查当前状态。**禁止以任何理由跳过验证轮**——包括但不限于"修复很简单"、"只是文档补充"、"不存在引入新问题的风险"、"可直接确认正确性"。这些都是 rationalization，不构成跳过验证的合法依据。
  - **暂停条件**：本轮存在无法判断的点 → 升级给用户裁决。用户裁决完成后，controller 根据继续/终止条件决定是否启动下一轮。
  - **终止条件**（满足任一即停止）：达到最大 3 轮；或经 controller 重新评估后，本轮无 Major 及以上级别的发现（即使 agent 标注了 Major，controller 判定实质为 Minor 则视为无 Major）。**注意**：若本轮存在被裁决为真 Major 的发现并已修复，仍属"本轮有 Major"，必须走继续条件启动下一轮验证，不得视为终止。

---

## DoR / DoD

### Definition of Ready（进入 Scenario 生成的门禁）

- ✅ 功能目标清晰
- ✅ 业务规则已定义（含已知边界规则）
- ✅ 范围有界
- ✅ 依赖项已知

如不清楚，AI 必须提出澄清问题。

### Definition of Done（任务完成检查清单）

- ✅ Plan Review 已完成（Epic 时适用）
- ✅ Spec 存在或已更新
- ✅ 场景已生成并审查
- ✅ 测试已实现（通过验证由 CI 负责）
- ✅ 跨 agent 审查 Test 已完成（标准模式按复杂度可选；Auto 模式强制）
- ✅ Red Run 通过（全部红色）
- ✅ 所有功能域已实现（不存在 stub）
- ✅ Spec 完整性矩阵已输出
- ✅ CI 验证通过（含 baseline 对比）
- ✅ 无关重构已避免
- ✅ 现有行为未被静默破坏
- ✅ Decision Report 已输出（Auto 模式适用）

---

## 参考文档索引

按需加载，不需要一次性阅读：

| 文档                                                                                         | 何时读取                                               |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| [references/workflow-standard.md](./references/workflow-standard.md)                         | 执行标准模式各步骤时                                   |
| [references/workflow-auto.md](./references/workflow-auto.md)                                 | 执行 Auto 模式时（裁决规则、Decision Log/Report 格式） |
| [references/workflow-epic.md](./references/workflow-epic.md)                                 | 处理 Epic 需求时（Plan 格式、Review 检查点）           |
| [references/complexity-guide.md](./references/complexity-guide.md)                           | 判断复杂度和审查深度时                                 |
| [references/iteration-rules.md](./references/iteration-rules.md)                             | 任何阶段发现问题需要回退时                             |
| [references/scenario-format.md](./references/scenario-format.md)                             | 生成或审查 Scenario 时                                 |
| [references/testing-guide.md](./references/testing-guide.md)                                 | 决定测什么/不测什么时                                  |
| [references/repo-structure.md](./references/repo-structure.md)                               | 创建测试文件或新模块时                                 |
| [references/prompt-spec-review.md](./references/prompt-spec-review.md)                       | 跨 agent 审查 Spec 时                                  |
| [references/prompt-scenario-generation.md](./references/prompt-scenario-generation.md)       | 生成 Scenario 时                                       |
| [references/prompt-scenario-review.md](./references/prompt-scenario-review.md)               | 跨 agent 审查 Scenario 时                              |
| [references/prompt-test-review.md](./references/prompt-test-review.md)                       | 跨 agent 审查 Test 时                                  |
| [references/prompt-test-implementation.md](./references/prompt-test-implementation.md)       | 实现测试时                                             |
| [references/prompt-feature-implementation.md](./references/prompt-feature-implementation.md) | 实现功能时                                             |
| [references/prompt-test-expansion.md](./references/prompt-test-expansion.md)                 | 需要补充测试场景时（备用）                             |
