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
- 每个阶段完成后必须更新 checkpoint，才能继续下一阶段

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

## 标准模式

标准模式下，`spec-driven-dev` 仍负责编排全流程，但在关键 stage gate 等待人工确认。详细步骤见 `workflows/standard.md`。

标准模式的主路径：

1. intake and route
2. clarify if needed
3. modeling
4. plan if epic
5. tech spec
6. test design and implementation
7. feature implementation
8. workflow verification and summary

## Auto 模式

Auto 模式下，`spec-driven-dev` 仍走完整阶段序列，但不会在普通 gate 处停下等待用户。详细规则见 `workflows/auto.md`。

Auto 模式的关键语义：

- 自动推进是**流程自动推进**，不是 orchestrator 自己吞掉 worker 边界
- 每个阶段的正式产物仍由对应 worker skill 生成
- orchestrator 维护 Decision Log / workflow summary 等编排级产物
- 需要独立第二视角时，通过 `multi-agent-loop` 发起阶段审查

## Epic 处理

Epic 的核心是：

1. 多单元建模
2. 生成并校验 plan
3. 按 plan 依赖顺序，把每个模块依次路由到 tech spec / test / implementation workers

详细规则见 `workflows/epic.md`。

## Stage Gate

### Gate 1: 进入建模前

- 已有原始需求或 `ClarifiedRequirement`
- 清晰度足够，或 blocker 已显式暴露

### Gate 2: 进入 tech spec 前

- `docs/models/<scenario>/<name>.md` 已就绪
- Epic 场景的 `plan` 已通过结构校验

### Gate 3: 进入 test 阶段前

- `tech-spec-writing` 已产出可消费的 `TechnicalSpec`
- 不存在会改变测试边界的 unresolved blockers

### Gate 4: 进入 implementation 前

- `test-design-and-implementation` 已产出可执行测试
- spec / tests / models 之间没有未解决语义冲突

### Gate 5: workflow 完成前

- `feature-implementation-from-spec` 已产出 `DeliveredChange`
- 当前 run 的关键验证结果已汇总
- `WorkflowCheckpoint` 已更新到最终状态

## Review Principles

本文档中的“独立审查”均指：通过 `multi-agent-loop` 启动独立进程执行阶段审查。

- Epic plan review 是最常见的独立审查点
- 其他阶段是否需要独立审查，跟随 worker skill 的规则或当前风险判断
- 审查 agent 只输出发现，controller 逐条裁决
- `multi-agent-loop` 的 bounded loop 规则完全沿用其自身 SKILL 定义

## Checkpoint And Handoff

`spec-driven-dev` 只保留两类 orchestration-specific 产物：

### StageHandoff

- 作用：把上一阶段已确认的输入边界路由给下一 worker
- 内容：当前阶段、来源产物、目标 worker、关键约束、blockers 摘要
- 不复制 worker 自己的详细模板

### WorkflowCheckpoint

- 作用：断点续接、阶段 gate、`--auto` 恢复执行
- 最少包含：当前阶段、上一步完成状态、context summary、已知 blockers

## Definition Of Done

从 orchestrator 视角，workflow 完成意味着：

- 需求已按需要经过澄清
- 建模文件已就绪
- Epic 场景的 plan 已校验通过
- `tech-spec-writing`、`test-design-and-implementation`、`feature-implementation-from-spec` 已按顺序被调用
- 当前 run 的最终状态可由 `DeliveredChange` + workflow summary 清晰说明
- `WorkflowCheckpoint` 已反映最终阶段与遗留风险

## 不覆盖范围

- 不自己维护 clarification 模板
- 不自己维护 technical spec 模板
- 不自己维护 test scenario / test implementation 模板
- 不自己维护 feature implementation 模板
- 不替代 `modeling-first`、`tech-spec-writing`、`test-design-and-implementation`、`feature-implementation-from-spec` 的阶段规则

## 引用资料

### 本 skill 自身

- `workflows/standard.md` — 标准模式的编排步骤
- `workflows/auto.md` — Auto 模式的编排规则
- `workflows/epic.md` — Epic 的建模 + plan + 模块路由规则
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
