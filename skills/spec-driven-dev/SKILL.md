---
name: spec-driven-dev
description: 强制执行规范驱动的 AI 开发工作流。所有开发需求走 Model → Spec → Scenarios → Tests → Implementation → CI 全流程。Epic 级需求先 Plan（模块拆解 + 依赖图 + 契约定义），再对每个模块独立走完整流程。支持 Auto 模式（--auto）：全流程自动化，AI 审查裁决，结束后输出 Decision Report。触发词：spec、plan、epic、模块拆解、开发规范、需求拆分、--auto。
metadata:
  version: 3.0
  tags:
    - ai-workflow
    - spec-driven
    - modeling
    - epic-planning
    - testing
    - development-process
---

# 规范驱动开发 Skill

## 建模集成

本 skill 将 `modeling-first`（原子 skill）作为流程内的**硬步骤**——与 `multi-agent-loop` 的集成方式相同：流程中直接调用，不可跳过。

- **全量建模**：目标模块尚无 `model.md`（或 Epic 尚无 `epic-model.md`）→ 调用 `modeling-first` 完整/轮廓模式从零产出
- **增量建模**：目标模块已有 `model.md` 且本次变更需要新增/修改领域信息 → 调用 `modeling-first` 在现有文件上增量更新（追加实体/关系/不变量/派生关系/锚点），经审查后继续 Spec 层
- **豁免**：本次变更符合 `modeling-first` SKILL.md Step 1 "不需要建模"清单（纯样式/bug fix/机械字段增删等）→ 在 DoR 中记录豁免理由，跳过建模步骤

`modeling-first` 方法论与模板（Entity/Rel/Invariant/Derivation/Aggregate/SharedInvariant 锚点命名空间）由其 SKILL 定义；本 skill 负责调用、消费产物、执行流程编排与机械校验。

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
① [Epic 建模] 调用 modeling-first 轮廓模式 → epic-model.md
   产出：实体 + 关系 + 聚合边界 + 跨聚合共享不变量
→ ② Plan（模块拆解 + 依赖图 + 契约，基于 epic-model.md）→ 详见 workflows/epic.md
→ ③ Human Plan Review（含上游对齐校验：聚合不跨模块、契约可追溯到 epic-model）
→ 对每个模块（按依赖顺序，可并行）：
     ④ [模块建模] 调用 modeling-first → <module>/model.md
        - 无 model.md → 全量建模（完整模式）
        - 已有 model.md → 增量建模（在现有文件上追加/修改条目）
        产出：完整实体 + 派生关系 + 不变量 + Reuse Check
     → ⑤ 独立执行 Spec 层流程（每个产出条目必须带 upstream-ref 指向建模锚点）
```

**关键约束**：Epic 流程**不允许跳过建模步骤**。`modeling-first` 作为本 skill 的内嵌硬步骤，产出 `epic-model.md` / `<module>/model.md`。没有建模文件会卡在 DoR。唯一豁免：符合 `modeling-first` skill Step 1 "不需要建模" 清单的场景（如纯样式/bug fix/机械字段增删）。

### Spec 层流程（每个模块）

```
0. 建模（始终执行，豁免需记录理由）           → 调用 modeling-first（全量或增量）
1. Spec 生成                                → 详见 workflows/standard.md#步骤1
2. 跨 agent 审查 Spec（按复杂度可选）          → 详见 workflows/standard.md#步骤2
3. 人工 Spec 审查 + DoR 校验                 → 详见 workflows/standard.md#步骤3
4. Scenario 生成                             → 详见 guides/scenario-format.md
5. 跨 agent 审查 Scenario（按复杂度可选）       → 详见 workflows/standard.md#步骤5
6. 人工 Scenario 审查                         → 详见 workflows/standard.md#步骤6
7. Test Implementation（含 Stub）              → 详见 workflows/standard.md#步骤7
8. 跨 agent 审查 Test（按复杂度可选）           → 详见 workflows/standard.md#步骤8
8.5 Red Run（始终执行）                        → 详见 workflows/standard.md#步骤8.5
9. 人工 Test 审查（按复杂度可选）               → 详见 workflows/standard.md#步骤9
10. Feature Implementation（含 Baseline）      → 详见 workflows/standard.md#步骤10
11. CI Verification                           → 详见 workflows/standard.md#步骤11
```

步骤 0、7、8.5、10、11 始终执行。其余步骤按复杂度调整深度（详见 guides/complexity.md）。

### 步骤 0 — 建模（详细规则）

调用 `modeling-first` skill 产出/更新建模文件。此步骤是流程内硬步骤，与 `multi-agent-loop` 的集成方式相同。

**全量建模**（目标模块无 `model.md`）：
- 调用 `modeling-first` 完整模式，从零产出 `<module>/model.md`
- 产出后经审查（标准模式：人工；Auto 模式：跨 agent 审查）再进入 Spec 层

**增量建模**（目标模块已有 `model.md`）：
- 评估本次变更是否引入新的领域信息（新实体/关系/不变量/派生关系/状态变化逻辑）
- 是 → 调用 `modeling-first`，在现有 `model.md` 上增量更新：追加新条目、修正已有条目、补充锚点
- 否 → 检查是否符合"不需要建模"清单，是则在 DoR 中记录豁免理由并跳过

**增量建模的约束**：
- 增量更新**必须**通过 `modeling-first` 执行（不得绕过 skill 直接手动编辑 `model.md`）
- 增量更新后，`model.md` 必须整体满足 `modeling-first` 的质量门槛（不只是新增部分）
- 已有锚点不得删除或重命名（除非下游所有 `upstream-ref` 同步更新）
- 增量更新后需重新验证（反向验证、派生验证、复用验证、最小性验证、可引用验证）

---

## Auto 模式流程

Auto 模式保留标准模式的**所有执行步骤**，仅将 Human Review 替换为 AI 跨 agent 审查 + AI 裁决。

**禁止中断**：除裁决升级条件外，不得以任何理由暂停流程。
**禁止简化审查**：每个模块的每个审查步骤必须完整执行跨 agent 审查，不得因"改动小"、"上下文长"等理由降级。
**Subagent 不替代流程**：subagent 只执行单步任务，不得将多个流程步骤打包；每步必须产出阶段性产物（Spec/Scenario 文件、Decision Log 等），缺产物禁止推进。
**步骤严格串行**：单个模块内的步骤 0→1→…→13 必须顺序执行，不得并行。原因：每个审查步骤可能触发回退修正，后续步骤依赖前置步骤的审查结果。
详细规则见 `workflows/auto.md`。

### Spec 层流程（每个模块）

```
0. 建模（调用 modeling-first，全量或增量）→ AI 跨 agent 审查建模 → AI 裁决 → Decision Log
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
① [Epic 建模]（modeling-first 轮廓模式 → epic-model.md；已有则增量更新）
→ AI 跨 agent 审查 epic-model（含建模完整性校验）→ AI 裁决 → Decision Log
→ ② Plan 生成（基于 epic-model.md）
→ AI 跨 agent 审查 Plan（含上游对齐校验：聚合不跨模块、契约可追溯）→ AI 裁决 → Decision Log
→ 对每个模块：
     ③ [模块建模]（调用 modeling-first → <module>/model.md；无则全量，有则增量）
     → AI 跨 agent 审查 模块建模 → AI 裁决 → Decision Log
     → 独立执行上方 Auto Spec 层流程（步骤 0 已在 ③ 完成，从步骤 1 起继续；每个产出带 upstream-ref）
     → 若模块建模期间发现 epic-model 有误，触发回流（详见 workflows/epic.md "迭代回流规则"）
→ 输出汇总 Decision Report（建模级 + Plan 级 + 各模块级，含 Upstream Coverage Matrix）
```

**Auto 模式下跨 agent 审查**：**必须且只能**通过 `multi-agent-loop` skill 启动——审查任务使用 **agent 角色**（独立 agent 执行审查这项任务）；**peer 角色仅用于对已有 agent 产出做第二视角挑战**（见 `multi-agent-loop/SKILL.md`）。详细工具级约束见下方"跨 Agent 审查原则"节。

各阶段审查任务的 prompt 模板：
- 建模审查（epic-model / model）：`prompts/upstream-review.md`
- Plan 审查：`prompts/plan-review.md`
- Spec 审查：`prompts/spec-review.md`
- Scenario 审查：`prompts/scenario-review.md`
- Test 审查：`prompts/test-review.md`

---

## 中途切换 Auto 模式

标准模式执行中，用户可随时指定 `--auto` 切换为 Auto 模式。

切换规则：

- **已完成的步骤保留**：人工已审查的 Spec/Scenario 不需要重新走 AI 审查
- **当前步骤起切换**：从用户指定 `--auto` 时的下一个未完成步骤开始，按 Auto 模式规则执行
- **部分完成的步骤**：如果当前步骤已产出产物但未审查（如 Scenario 已生成但未审查），从该步骤的审查环节开始按 Auto 模式执行；如果当前步骤进行到一半（如测试写了一部分），从该步骤的开头重新执行
- **Decision Log 从切换点开始记录**：切换前的人工审查不纳入 Decision Log
- **Decision Report 标注切换点**：报告开头注明"从步骤 N 起切换为 Auto 模式"，以及切换前已由人工完成的步骤清单

示例：

```
用户：Spec 我已经审查通过了，后面 --auto 帮我走完
→ 从步骤 4（Scenario 生成）开始自动执行
→ 步骤 1-3 标记为"人工已完成"，步骤 4-13 按 Auto 模式规则执行

用户：Scenario 生成好了但我没时间审了，--auto
→ 从步骤 5（跨 agent 审查 Scenario）开始自动执行
→ 步骤 1-3 标记为"人工已完成"，步骤 4 标记为"产物已生成"
```

---

## 迭代修正机制

任何阶段发现问题，允许回退上一步。详细回退规则见 `guides/iteration-rules.md`。

**关键原则**：

**标准模式**：

- Spec 和 Scenario 是人审查的，发现问题必须回退到人审查环节
- Plan 是模块边界和契约的唯一真理源，不允许在 Spec 层悄悄扩展边界
- 不允许 AI 自行修改 Spec、Scenario 或 Plan 的语义

**Auto 模式例外**：

- AI 可在裁决权限范围内修改 Spec/Scenario/Plan，但每次必须记录 Decision Log（含变更前后对照）
- 超出裁决权限的修改仍必须升级给用户

### 进度检查点

流程执行中，进度状态嵌入已有产物文件（不创建额外文件），使新会话能从断点续接。

**单模块级**：进度嵌入 `spec/<module>.md` 的 YAML frontmatter：

```yaml
---
module: order
current_step: 7
current_step_name: Test Implementation
status: in_progress          # pending | in_progress | done | blocked:<原因>
last_completed_step: 6
last_completed_step_name: Scenario Review
context_summary: |
  Spec 已审查通过，3 条 Rule。Scenario 12 个，含 2 个 CRITICAL。
  审查轮次：Spec 2轮，Scenario 1轮，均无 Major。
decision_log_ref: $TMPDIR/spec-driven-dev-1713072000/decision-log.md
updated: 2026-04-14T10:30
---
```

**Epic 级**：`plan.md` 尾部追加宏观进度索引，每个模块一行。详细上下文（`context_summary`、`decision_log_ref`）仍在各模块的 `spec/<module>.md` frontmatter 中：

```markdown
## Progress

| 模块 | 步骤 | 状态 | 备注 |
|------|------|------|------|
| order | 7 Test Implementation | in_progress | 详见 spec/order.md frontmatter |
| payment | 1 Spec 生成 | in_progress | |
| notification | — | pending | 依赖 order |
```

**更新时机**：每个步骤完成后立即更新 `spec/<module>.md` frontmatter + plan.md Progress 表（Epic 时）。这是硬性要求。

**续接协议**（新会话恢复执行时）：

1. **定位**：读 `plan.md` 尾部 Progress 表（Epic）或 `spec/<module>.md` frontmatter（单模块），确定当前模块和步骤
2. **恢复上下文**：读该模块 `spec/<module>.md` frontmatter 的 `context_summary`（裁决摘要、审查状态、已知问题）
3. **恢复 Decision Log**：读 `decision_log_ref` 指向的 `$TMPDIR` 文件（若已被 OS 清理则标记为"Decision Log 已丢失，仅以产物为准"，不阻塞继续执行）
4. **继续执行**：`status: in_progress` 从该步骤头重做，`last_completed_step` 之后的步骤正常推进

### Context 压力处理

**"上下文太长"不是中断理由，也不是简化审查的理由——而是触发压缩并继续的信号。**

当 agent 感知到 context 接近上限时（如工具返回截断提示、模型输出被截断、或主观判断 context 已很长），执行以下操作：

1. **写检查点**：立即更新当前模块的 frontmatter / plan.md Progress（确保进度持久化）
2. **将 Decision Log 写入 `$TMPDIR`**（若尚未写入）
3. **压缩上下文**：使用 `/compact` 或等效的 context 压缩机制，保留：
   - 当前步骤的输入产物（Spec / Scenario / 当前正在处理的文件路径）
   - 未完成的工作描述
   - 丢弃：已完成步骤的中间输出、历史审查日志、已裁决的 Decision Log 全文（摘要已在 frontmatter）
4. **继续执行**：压缩后从当前步骤继续，不因 context 压力额外暂停

**与人工审查的关系**：标准模式下的人工审查步骤（Spec/Scenario/Test 人工审查）是流程设计的合法等待点，不受 context 压力处理影响。Context 压力处理的"不暂停"指的是：不以 context 为由在人工审查之外增加额外暂停。若 context 压力恰好在人工审查前触发，执行写检查点 → 压缩 → 进入人工审查等待（正常流程）。

**禁止的行为**：
- 以"上下文太长"为由在非人工审查步骤中断流程等待用户
- 以"上下文太长"为由跳过审查步骤或降级审查深度
- 以"上下文太长"为由将多个步骤打包交给 subagent

**此规则适用于所有模式**（标准模式和 Auto 模式均适用）。

### 跨 Agent 审查原则

本文档中所有"跨 agent 审查"均指：**使用 `multi-agent-loop` skill 启动一个独立的审查进程**。优先选择与当前 coding agent 不同的 agent（如当前是 Claude 则启动 Codex/OpenCode），以获得独立视角。若环境中不存在其他可用的 coding agent，允许使用同一 agent 但必须通过 `multi-agent-loop` 启动独立进程，确保审查上下文与执行上下文隔离。

**工具级约束**：跨 agent 审查**必须且只能**通过 `multi-agent-loop` skill（即 `run_agent.sh`）启动。**禁止使用 Agent tool（subagent）替代**——Agent tool 启动的 subagent 与当前会话共享模型和上下文来源，不构成独立审查。即使 subagent 的上下文是隔离的，它仍然不等于 `multi-agent-loop` 的跨进程审查。

执行要点：

- **优先异构**：审查 agent 优先选择与当前执行 agent 不同的 agent；无可用异构 agent 时，使用同一 agent 但必须通过 `multi-agent-loop`（`run_agent.sh`）启动独立进程
- **使用 agent 角色**：跨 agent 审查是"执行审查任务"，必须使用 `multi-agent-loop` 的 **agent 角色**（非 peer）。peer 角色仅在需要挑战 agent 已有结论时使用。任务文件必须命名为 `agent-task.md`（遵循 `multi-agent-loop` 文件协议），不得使用自定义文件名
- **轮次隔离**：每一轮审查都必须使用新的 `task-name`，不得复用上一轮目录。推荐命名为 `<step>-<module>-r1`、`<step>-<module>-r2`、`<step>-<module>-r3`
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
- ✅ **建模文件已就绪**（本模块/本 Epic 的领域真理源）——由步骤 0 保证，满足以下任一：
  - 已通过 `modeling-first` 产出/增量更新 `model.md`（单模块）或 `epic-model.md`（Epic）+ 所属各 `<module>/model.md`
  - 或在步骤 0 明确记录"本阶段无需建模"的豁免理由，且场景符合 `modeling-first` 的"不需要建模"清单（Step 1）
- ✅ **建模文件可引用**：每条实体/关系/不变量/派生关系/聚合都带显式锚点（格式和命名空间见 `guides/upstream-ref.md`）。供下游产出标注 `upstream-ref`

如不清楚，AI 必须提出澄清问题。

### Definition of Done（任务完成检查清单）

- ✅ Plan Review 已完成（Epic 时适用）
- ✅ **Upstream Coverage Matrix 已产出且完整**：建模文件中**每条带锚点的条目**（实体/关系/不变量/派生关系/聚合/共享不变量——即六类锚点命名空间）在矩阵中都有对应的 Spec 场景 / Test / Impl，或显式标注 `NOT APPLICABLE + 理由`（详见 `guides/upstream-coverage.md`）
- ✅ **所有产出条目 upstream-ref 合法**：Plan 的"持有聚合/模块依赖/产出契约"、Spec 的每条 Rule / State / State Transition、每个 Scenario、每个 Test、Impl 的 Coverage Matrix 条目，`upstream-ref` 都能在 `model.md` / `epic-model.md` 中找到对应锚点；不得存在虚假引用（由 `scripts/check-upstream-coverage.sh` 机械校验）
- ✅ Spec 存在或已更新
- ✅ Spec 审查已完成（标准模式：人工审查；Auto 模式：跨 agent 审查）
- ✅ 场景已生成并审查
- ✅ 测试已实现（通过验证由 CI 负责）
- ✅ 跨 agent 审查 Test 已完成（标准模式按复杂度可选；Auto 模式强制）
- ✅ Red Run 通过（当前 Spec 范围内测试全部红色）
- ✅ Baseline Test Run 已记录
- ✅ 所有功能域已实现（不存在 stub）
- ✅ Spec 完整性矩阵已输出
- ✅ CI 验证通过（含 baseline 对比、coverage gate、mutation score gate — 由 `test-quality-gate` skill 提供）
- ✅ 无关重构已避免
- ✅ 现有行为未被静默破坏
- ✅ Decision Report 已输出（Auto 模式适用）

---

## 参考文档索引

按需加载，不需要一次性阅读：

### 流程定义（workflows/）

| 文档 | 何时读取 |
|------|---------|
| [workflows/standard.md](./workflows/standard.md) | 执行标准模式各步骤时 |
| [workflows/auto.md](./workflows/auto.md) | 执行 Auto 模式时（裁决规则、Decision Log/Report 格式）|
| [workflows/epic.md](./workflows/epic.md) | 处理 Epic 需求时（Plan 格式、Review 检查点）|

### 任务指令（prompts/）

| 文档 | 何时读取 |
|------|---------|
| [prompts/spec-review.md](./prompts/spec-review.md) | 跨 agent 审查 Spec 时 |
| [prompts/scenario-generation.md](./prompts/scenario-generation.md) | 生成 Scenario 时 |
| [prompts/scenario-review.md](./prompts/scenario-review.md) | 跨 agent 审查 Scenario 时 |
| [prompts/test-implementation.md](./prompts/test-implementation.md) | 实现测试时 |
| [prompts/test-review.md](./prompts/test-review.md) | 跨 agent 审查 Test 时 |
| [prompts/test-expansion.md](./prompts/test-expansion.md) | 需要补充测试场景时（备用）|
| [prompts/feature-implementation.md](./prompts/feature-implementation.md) | 实现功能时 |
| [prompts/upstream-review.md](./prompts/upstream-review.md) | 跨 agent 审查建模文件时 |
| [prompts/plan-review.md](./prompts/plan-review.md) | 跨 agent 审查 Plan 时 |

### 规则与指南（guides/）

| 文档 | 何时读取 |
|------|---------|
| [guides/upstream-ref.md](./guides/upstream-ref.md) | upstream-ref 语法、锚点命名（唯一定义点）|
| [guides/testing.md](./guides/testing.md) | 测什么/不测什么/Stub/Red Run/禁止事项（唯一定义点）|
| [guides/upstream-coverage.md](./guides/upstream-coverage.md) | Upstream Coverage Matrix 格式、机械校验规则 |
| [guides/scenario-format.md](./guides/scenario-format.md) | 生成或审查 Scenario 时 |
| [guides/complexity.md](./guides/complexity.md) | 判断复杂度和审查深度时 |
| [guides/iteration-rules.md](./guides/iteration-rules.md) | 任何阶段发现问题需要回退时 |
| [guides/repo-structure.md](./guides/repo-structure.md) | 创建测试文件或新模块时 |

### 其他

| 文档 | 何时读取 |
|------|---------|
| [modeling-first/SKILL.md](../modeling-first/SKILL.md) | 执行步骤 0 建模时（全量或增量）|
| [templates/spec.md](./templates/spec.md) | 生成 Spec 时（步骤 1，含 frontmatter 进度检查点）|
| [templates/plan.md](./templates/plan.md) | 生成 Plan 时（Epic 模式，含 Progress 进度表）|
