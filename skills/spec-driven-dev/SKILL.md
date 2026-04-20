---
name: spec-driven-dev
description: 规范驱动开发的顶层流程编排器。负责按阶段调用 requirements-clarification、modeling-first、tech-spec-writing、test-design-and-implementation、feature-implementation-from-spec，并在 `--auto` 下自动推进全流程。触发词：spec、plan、epic、模块拆解、开发规范、需求拆分、--auto。
metadata:
  version: 4.0
  tags:
    - ai-workflow
    - spec-driven
    - orchestration
    - modeling
    - epic-planning
    - development-process
---

# 规范驱动开发 Skill

`spec-driven-dev` 是**顶层流程编排器**，不是 all-in-one 的内容生产 skill。

它负责：

- 作为规范驱动开发的默认总入口
- 判断是否先走 `requirements-clarification`
- 强制接入 `modeling-first`
- 在 Epic 场景生成和校验 `plan`
- 按阶段调用 `tech-spec-writing`、`test-design-and-implementation`、`feature-implementation-from-spec`
- 维护 stage gate、回退、续接、升级边界
- 在 `--auto` 下自动推进全流程

它**不再深度维护**各阶段的详细内容模板。clarification / tech spec / test / implementation 的模板、checklist、golden examples 和阶段 prompts 应由对应 worker skill 持有。

## Worker Map

| 阶段 | 默认 worker | `spec-driven-dev` 负责什么 |
|------|-------------|----------------------------|
| Requirement clarity | `requirements-clarification` | 判断是否需要澄清、消费 ClarifiedRequirement |
| Modeling | `modeling-first` | 强制建模、消费 `docs/models/<scenario>/<name>.md` |
| Planning (Epic) | `spec-driven-dev` + `templates/plan.md` | 产出/校验 plan、维护模块边界和依赖 |
| Tech spec | `tech-spec-writing` | 路由阶段输入、检查进入 test 的 gate |
| Test design + implementation | `test-design-and-implementation` | 路由批准 spec、检查进入 impl 的 gate |
| Feature implementation | `feature-implementation-from-spec` | 路由 spec + tests + models、汇总交付状态 |
| Independent review | `multi-agent-loop` | 在需要独立第二视角时发起阶段审查 |

## 核心原则

- `spec-driven-dev` 保留完整流程入口地位
- `--auto` 仍表示自动推进模式
- orchestrator 负责流程语义，不重复维护 worker 的内容语义
- 所有新领域信息必须先经过 `modeling-first`
- Epic 先建模，再 plan，再按模块推进 worker stages
- 每个阶段完成后必须更新并落盘 checkpoint，才能继续下一阶段

## 入口判断

收到开发需求时，判断三个维度：

### 1. 模式

- 指定 `--auto` → **Auto 模式**：`spec-driven-dev` 自动编排各阶段 worker，直到最终 workflow summary
- 未指定 → **标准模式**：在关键 gate 等待人工确认
- 中途切换到 `--auto` → 从当前未完成阶段继续自动推进

### 2. 清晰度

- 需求模糊、缺少 `goal / actors / trigger / scope / acceptance signals` 中的关键信息 → 先调用 `requirements-clarification`
- 需求已经足够清晰 → 直接进入建模

### 3. 规模

- 跨多个模块、有显式依赖或需要模块边界/契约 → **Epic**，必须先走 plan
- 单模块可承载 → 不产出 plan，直接走后续 worker stages

## 13 步阶段序列

`spec-driven-dev` 的主阶段序列在 Standard / Auto / Epic 三种模式下共享骨架，每个内容阶段后面紧跟一个对应的 Review 阶段：

```
1.  Intake And Route
2.  Clarify If Needed
3.  Modeling
4.  Modeling Review               ← prompts/upstream-review.md
    (或 Modeling Exemption Review  ← prompts/exemption-review.md)
5.  Plan If Epic
6.  Plan Review (Epic only)       ← prompts/plan-review.md
7.  Tech Spec
8.  Spec Review                   ← prompts/spec-review.md
9.  Test Design And Implementation
10. Test Review                   ← prompts/test-review.md
11. Feature Implementation
12. Implementation Review         ← prompts/impl-review.md
13. Workflow Verification And Summary
```

Review 阶段的执行机制统一走 `multi-agent-loop`（agent 角色，task-name `<stage>-<module>-r1..r3`，默认 runner 优先级 `opencode > claude > codex > crush`）。

## 标准模式

标准模式下，`spec-driven-dev` 仍负责编排全流程，在关键 stage gate 等待人工确认。Review 阶段**是否执行**按 `guides/complexity.md` 的复杂度判断（Trivial/Simple 可跳过，Medium/Complex 建议或强制执行；Modeling Exemption Review 和 Plan Review 任何情况下都强制）。

详细步骤见 `workflows/standard.md`。

## Auto 模式

Auto 模式下，`spec-driven-dev` 走完整 13 步序列，**每个 Review 阶段都强制执行**，不在普通 gate 处停下等待用户。只有触发升级边界时才暂停。

详细规则见 `workflows/auto.md`。

Auto 模式的关键语义：

- 自动推进是**流程自动推进**，不是 orchestrator 自己吞掉 worker 边界
- 每个内容阶段的正式产物仍由对应 worker skill 生成
- 每个 Review 阶段由 `multi-agent-loop` 发起独立 runner 执行，controller 逐条裁决
- orchestrator 维护 Decision Log / workflow summary 等编排级产物

## Epic 处理

Epic 的核心是：

1. 多单元建模
2. 生成并校验 plan
3. 按 plan 依赖顺序，把每个模块依次路由到 tech spec / test / implementation workers

详细规则见 `workflows/epic.md`。

## Stage Gate

13 步序列中每个内容阶段→内容阶段的转换都有一个 gate，gate 的基本要求是：**上一内容阶段正式产物已产出 + 对应 Review 阶段已收敛（或按当前模式下的跳过规则合法跳过）**。Review 跳过规则见 `guides/complexity.md` 与 `workflows/standard.md`。

### Gate 1: 进入建模（步骤 3）前

- 已有原始需求或 `ClarifiedRequirement`
- 清晰度足够，或 blocker 已显式暴露

### Gate 2: 进入 Tech Spec（步骤 7）前

- 步骤 3 产物就绪：`docs/models/<scenario>/<name>.md` 或已批准的 `modeling_exemption`
- 若走正常建模：步骤 4 Modeling Review 已收敛（auto 强制；standard 按 `guides/complexity.md` 判断，允许合法跳过）
- 若走建模豁免：步骤 4' Modeling Exemption Review 已收敛（任意模式任意复杂度均强制，不可跳过）
- Epic 场景：`plan.md` 已通过 `scripts/check-plan-structure.sh` + `scripts/check-upstream-coverage.sh`，且步骤 6 Plan Review 已收敛（任意模式均强制）

### Gate 3: 进入 Test Design（步骤 9）前

- 步骤 7 产物就绪：`TechnicalSpec.Status = Ready for test/design`
- 步骤 8 Spec Review 已收敛或合法跳过
- 不存在会改变测试边界的 unresolved blockers

### Gate 4: 进入 Feature Implementation（步骤 11）前

- 步骤 9 产物就绪：Test Scenarios `Status = Ready for implementation` + Executable Tests + Red Run 结果
- 步骤 10 Test Review 已收敛或合法跳过
- spec / tests / models 之间没有未解决语义冲突

### Gate 5: 进入 Workflow Verification（步骤 13）前

- 步骤 11 产物就绪：`DeliveredChange.Status = Delivered`
- 步骤 12 Implementation Review 已收敛或合法跳过
- 当前 run 的关键验证结果已汇总

### Gate 6: Workflow 完成前（步骤 13 的出口）

- Upstream Coverage Matrix 已产出并通过 `scripts/check-upstream-coverage.sh`（结构与必测条目见 `guides/upstream-coverage.md`）
- `WorkflowCheckpoint` 已更新到最终状态
- workflow summary 已输出给用户

## Review Principles

本文档中的"独立审查"均指：通过 `multi-agent-loop` 启动独立进程执行阶段审查。

- Review 阶段是 13 步序列中与内容阶段同级的编号步骤（步骤 4 / 6 / 8 / 10 / 12），不是 side note
- 每个 Review 阶段都有对应的 prompt 文件（`prompts/*-review.md`）
- Auto 模式：全部 Review 阶段强制执行
- Standard 模式：Review 阶段按 `guides/complexity.md` 触发（Modeling Exemption Review 和 Plan Review 例外，始终强制）
- 审查角色固定为 `agent`（peer 只在需要第二视角挑战已有审查时才用）
- 审查 agent 只输出发现，controller 逐条裁决并写 `agent-judgment.md`
- `multi-agent-loop` 的 bounded loop 规则（最大 3 轮、继续/终止/升级判定）完全沿用其自身 SKILL 定义
- 默认 runner 优先级：`opencode > claude > codex > crush`

## Checkpoint And Handoff

`spec-driven-dev` 只保留两类 orchestration-specific 产物：

### StageHandoff

- 作用：把上一阶段已确认的输入边界路由给下一 worker
- 内容：当前阶段、来源产物、目标 worker、关键约束、blockers 摘要
- 不复制 worker 自己的详细模板
- **Producer**：orchestrator 在每个 stage 完成时产出（Epic 模块路由时按模块产出）
- **Consumer**：下游 worker 的入口消费，作为 routing input 与输入边界依据
- **持久化**：默认只作为 orchestrator 会话内的路由载体，不强制落盘；需要跨会话续接时以 `WorkflowCheckpoint` 的 Context Summary 承载关键字段

### WorkflowCheckpoint

- 作用：断点续接、阶段 gate、`--auto` 恢复执行
- 最少包含：当前阶段、上一步完成状态、`Context Summary`（跨阶段累积摘要，下一会话冷启动的单一续接基线）、已知 blockers
- **Producer**：orchestrator 在每个阶段完成后立即更新 `Context Summary` 并落盘
- **Consumer**：下一次会话启动时由 orchestrator 读取，定位续接点
- **持久化**：每个阶段完成后必须落盘（workflow 续接的唯一可靠来源，与宿主会话状态解耦）
  - Epic 场景：落到 `plan.md` 的 Progress 表及相邻同目录位置（Epic 多 session 并行时按 `workflows/epic.md` 的命名约定，每模块一个文件）
  - 单模块场景：推荐 `.spec-driven-dev/workflow-checkpoint.md`

## Definition Of Done

从 orchestrator 视角，workflow 完成意味着：

- 需求已按需要经过澄清
- 建模文件已就绪
- Epic 场景的 plan 已校验通过
- `tech-spec-writing`、`test-design-and-implementation`、`feature-implementation-from-spec` 已按顺序被调用
- 当前 run 的最终状态可由 `DeliveredChange` + workflow summary 清晰说明
- `WorkflowCheckpoint` 已反映最终阶段与遗留风险
- Upstream Coverage Matrix 已产出并通过机械校验，workflow summary 包含最终 Matrix

## 不覆盖范围

- 不自己维护 clarification 模板
- 不自己维护 technical spec 模板
- 不自己维护 test scenario / test implementation 模板
- 不自己维护 feature implementation 模板
- 不替代 `modeling-first`、`tech-spec-writing`、`test-design-and-implementation`、`feature-implementation-from-spec` 的阶段规则

## 引用资料

### 本 skill 自身

- `guides/complexity.md` — 标准模式下的复杂度分级与 Review 阶段触发规则
- `workflows/standard.md` — 标准模式的 13 步编排步骤
- `workflows/auto.md` — Auto 模式的编排规则（Review 强制执行）
- `workflows/epic.md` — Epic 的建模 + plan + 按模块路由 + 每模块 Review 规则
- `prompts/upstream-review.md` — Modeling Review 提示（步骤 4）
- `prompts/exemption-review.md` — Modeling Exemption Review 提示（步骤 4'）
- `prompts/plan-review.md` — Plan Review 提示（步骤 6，Epic 强制）
- `prompts/spec-review.md` — Spec Review 提示（步骤 8）
- `prompts/test-review.md` — Test Review 提示（步骤 10，编排级）
- `prompts/impl-review.md` — Implementation Review 提示（步骤 12）
- `templates/plan.md` — Epic plan 模板
- `templates/stage-handoff.md` — orchestration-specific stage handoff 模板
- `templates/workflow-checkpoint.md` — orchestration-specific workflow checkpoint 模板
- `scripts/check-plan-structure.sh` — plan 结构校验
- `scripts/check-upstream-coverage.sh` — upstream anchor / coverage 校验

### 上游 / 下游 worker skills

- `../requirements-clarification/SKILL.md`
- `../modeling-first/SKILL.md`
- `../tech-spec-writing/SKILL.md`
- `../test-design-and-implementation/SKILL.md`
- `../feature-implementation-from-spec/SKILL.md`
- `../multi-agent-loop/SKILL.md`
