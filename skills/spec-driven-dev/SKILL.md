---
name: spec-driven-dev
description: 规范驱动开发顶层编排器；按阶段路由 worker skills，并在 `--auto` 下自动推进。触发词：spec、plan、epic、模块拆解、开发规范、需求拆分、--auto。
metadata:
  version: 4.2.0
  tags:
    - ai-workflow
    - spec-driven
    - orchestration
    - modeling
    - epic-planning
    - development-process
---

# Spec Driven Dev

## What

`spec-driven-dev` 是规范驱动开发的顶层 controller。它把开发需求编排成一条可续接、可审查、可验证的阶段链路：澄清、建模、规格、测试、实现、审查和总结。

它不生产各阶段的详细内容。内容由对应 worker skill 负责，controller 只维护路由、gate、checkpoint、review decision 和 workflow summary。

## Why

本流程解决的核心问题是：不要从模糊需求直接跳到实现，也不要让实现反向定义规格和测试。

它保证：

- 需求不清时先澄清
- 新领域信息先建模
- 规格先于测试，测试先于实现
- 内容产物先审查，再进入下一阶段
- 中断后能从 `WorkflowCheckpoint` 恢复

## How

1. 识别运行模式：Standard、Auto 或 Epic。
2. Controller 按需澄清；复杂澄清在用户输入齐后可委派 `requirements-clarification`。
3. 调用 `modeling-first`，或走已批准的 modeling exemption。
4. 为内容阶段写 `StageHandoff`，通过宿主 subagent / Task 启动对应 Stage Worker。
5. 收集 `StageResult`，更新 `WorkflowCheckpoint` 和 `DecisionLog`。
6. 对完成的内容阶段执行或记录 Review Decision。
7. gate 通过后进入下一阶段；最终运行机械校验并输出 summary。

## 架构设计

`SKILL.md` 是流程本体；其它文件只补充本文件中的某个模式、阶段、产物或校验，不重新定义主流程。

| 层 | 负责 | 文件 |
|----|------|------|
| Controller | 入口路由、stage gate、checkpoint、review decision、summary | `SKILL.md` |
| Mode Workflow | Standard / Auto / Epic 的模式差异 | `workflows/*.md` |
| Guide | 横切规则与阶段执行补充 | `guides/*.md` |
| Worker Skill | 内容阶段的语义、模板和质量门槛 | 相邻 worker skill |
| Review Prompt | 阶段审查清单和输出要求 | `prompts/*.md` |
| Template | 编排产物字段格式 | `templates/*.md` |
| Script | 可机械验证的 gate | `scripts/*.sh` |

负向边界：`prompts/` 不决定是否启动 Review 或推进下一阶段；`templates/` 不定义流程语义或 worker 内容语义；`scripts/` 不替代 controller judgment 或 worker 规则。

核心边界：`multi-agent-loop` 只用于 Review，不用于内容阶段生产。

## 角色描述

| 角色 | 负责 | 不负责 |
|------|------|--------|
| Controller / Orchestrator | 路由入口、写 handoff、启动 worker/reviewer、裁决 gate、更新 checkpoint、输出 summary | 不生产 worker 内容产物，不吞掉 Review judgment |
| Stage Worker | 作为宿主 subagent / Task 加载目标 worker skill，消费 `StageHandoff`，生产正式 artifact 和 `StageResult` | 不直接与用户交互，不决定 workflow 是否进入下一阶段，不改写流程 gate |
| Reviewer | 按 `guides/review.md` 和对应 `prompts/*-review.md`，通过 `multi-agent-loop` 独立审查已产出 artifact，输出 findings | 不直接修复，不裁决 findings 是否成立，不推进流程 |

## 工作流程

### 入口路由

| 条件 | 路由 |
|------|------|
| 指定 `--auto` | Auto：自动推进，遇升级边界才暂停 |
| 未指定 `--auto` | Standard：关键 gate 等待人工确认 |
| 跨多个模块或需要模块契约 | Epic：先建模再 plan |
| 缺少 goal / actors / trigger / scope / acceptance signals | 先澄清 |
| 输入明确且单模块可承载 | 直接建模 |

### Stage Registry

方括号标注该步骤的 primary executor。多角色步骤不把所有角色塞进标题；协作角色写在下一行。Controller 始终拥有 gate 裁决权。

| Step No. | Stage key | Stage name | Primary role | Executor / skill | StageResult key | Review result key | Review prompt |
|----------|-----------|------------|--------------|------------------|-----------------|-------------------|---------------|
| 1 | `intake` | `[Controller]: Intake And Route` | Controller | N/A | N/A | N/A | N/A |
| 2 | `clarification` | `[Controller]: Clarify If Needed` | Controller | optional `requirements-clarification` | `<module>/clarification` | N/A | N/A |
| 3 | `modeling` | `[Stage Worker]: Modeling` | Stage Worker | `modeling-first` | `<module>/modeling` | `<module>/modeling` | `prompts/upstream-review.md` or `prompts/exemption-review.md` |
| 4 | `modeling-review` / `exemption-review` | `[Reviewer]: Modeling Review / Modeling Exemption Review` | Reviewer | `multi-agent-loop` | N/A | same as reviewed content key | see Step 3 |
| 5 | `plan` | `[Controller]: Plan If Epic` | Controller | N/A | `_workflow/plan` | `_workflow/plan` | `prompts/plan-review.md` |
| 6 | `plan-review` | `[Reviewer]: Plan Review` | Reviewer | `multi-agent-loop` | N/A | `_workflow/plan` | `prompts/plan-review.md` |
| 7 | `tech-spec` | `[Stage Worker]: Tech Spec` | Stage Worker | `tech-spec-writing` | `<module>/tech-spec` | `<module>/tech-spec` | `prompts/spec-review.md` |
| 8 | `spec-review` | `[Reviewer]: Spec Review` | Reviewer | `multi-agent-loop` | N/A | same as reviewed content key | `prompts/spec-review.md` |
| 9 | `test-design-and-implementation` | `[Stage Worker]: Test Design And Implementation` | Stage Worker | `test-design-and-implementation` | `<module>/test-design-and-implementation` | `<module>/test-design-and-implementation` | `prompts/test-review.md` |
| 10 | `test-review` | `[Reviewer]: Test Review` | Reviewer | `multi-agent-loop` | N/A | same as reviewed content key | `prompts/test-review.md` |
| 11 | `feature-implementation` | `[Stage Worker]: Feature Implementation` | Stage Worker | `feature-implementation-from-spec` | `<module>/feature-implementation` | `<module>/feature-implementation` | `prompts/impl-review.md` |
| 12 | `impl-review` | `[Reviewer]: Implementation Review` | Reviewer | `multi-agent-loop` | N/A | same as reviewed content key | `prompts/impl-review.md` |
| 13 | `verification` / `epic-summary` | `[Controller]: Workflow Verification And Summary` | Controller | N/A | N/A | N/A | N/A |

非 Epic 场景跳过 `plan` / `plan-review`。Epic 在 Plan 之后按模块重复步骤 7-12。Review stage 执行细节见 `guides/review.md`。

`<module>` 在 Epic 模块步骤使用 plan 模块名，Epic 级步骤使用 `_workflow`，非 Epic 固定为 `single`。`Stage Results` 与 `Review Results` 必须使用同一个被审查内容 key 配对，例如 `payment/tech-spec`；Review stage 自身不创建 `StageResult`。

### 编排契约

| Artifact | 是否落盘 | 默认路径规则 |
|----------|----------|--------------|
| `StageHandoff` | 是；内容阶段需要，Review stage 不使用 | `.spec-driven-dev/<run>/<module>/<stage-key>/handoff.md` |
| `StageResult` | 是；内容阶段和 Epic Plan 需要 | `.spec-driven-dev/<run>/<module>/<stage-key>/stage-result.md` |
| `WorkflowCheckpoint` | 是；每个阶段完成后必须更新 | `.spec-driven-dev/<run>/<module>/checkpoint.md` |
| `DecisionLog` | 是；追加写入日志文件，不是每条一个文件 | `.spec-driven-dev/<run>/<module>/decision-log.md` |

`<run>` 在 Epic 场景使用 Epic name，非 Epic 固定为 `single`。`<module>` 与 `<stage-key>` 按 Stage Registry 取值。`Stage Results`、`Review Results`、`Artifact Index` 与 `DecisionLog.当前阶段` 的索引 key 统一写成 `<module>/<stage-key>`。

Review artifact 仍由 `multi-agent-loop` 写入 `.agent-loop/<task-name>/r<N>/agent-output.md` 和 `agent-judgment.md`；`.spec-driven-dev` 只在 checkpoint / decision log 中登记 review result 路径和 controller judgment 摘要。若用户或项目选择不同路径，Controller 必须在首次 `DecisionLog` 和 `WorkflowCheckpoint.Context Summary` 中记录实际路径。后续所有 checkpoint 索引以实际路径为准。

首次创建 `.spec-driven-dev/<run>/` 之前，Controller 必须运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/ensure-workdir-exclude.sh [workdir]`，把 `.spec-driven-dev/` 写入 `<workdir>/.git/info/exclude`（per-clone 级，不修改团队 .gitignore；幂等，多次调用安全），避免编排产物污染项目工作树。对应 multi-agent-loop 的 `.agent-loop/` exclude 处理。

进入下一内容阶段前，上一内容阶段必须有正式 artifact、`StageResult.Status = done`、Review Decision 和已落盘 checkpoint。

### 审查契约

- `executed:<review-result-path>`：按 `guides/review.md` 启动 `multi-agent-loop`，加载对应 review prompt，并完成 controller judgment。
- `skipped:<complexity + reason>`：仅 Standard 模式允许，且必须符合 `guides/complexity.md`。

Auto 模式下 Review Decision 只能是 `executed`。Clarification 阶段不设独立 Review。

非法状态：`StageResult.Status = done` 后，`Next Action` 不得直接指向下一 content worker；必须先完成 Review Decision 并更新 `WorkflowCheckpoint.Review Results`。

### 不可跳过校验

- 引用建模单元时运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh`。
- Epic plan 运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-plan-structure.sh`，并执行 Plan Review。
- Workflow Verification 完成前运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-review-results.sh` 校验 `WorkflowCheckpoint.Stage Results` / `Review Results` 配对。
- 走 modeling exemption 时执行 Modeling Exemption Review。

### 补充文件

- Standard：`workflows/standard.md`
- Auto：`workflows/auto.md`
- Epic：`workflows/epic.md`
- Review stage execution：`guides/review.md`

### 完成定义

workflow 完成意味着：澄清已按需完成，建模或豁免已就绪，规格/测试/实现按序完成，每个内容阶段都有 `StageHandoff`、`StageResult` 和 Review Decision，checkpoint 与机械校验通过，最终状态可由 `DeliveredChange` 和 summary 说明。

## 引用资料

路径相对 skill 安装目录，即包含本 `SKILL.md` 的目录。

脚本与模板随 skill 一起分发，运行时直接从 skill 目录调用；不需要复制到目标项目仓库。目标项目里没有这些脚本不是合法跳过理由。命令示例中的 `$SPEC_DRIVEN_DEV_SKILL_DIR` 指本 skill 安装目录的绝对路径。

- `workflows/*.md` — Standard / Auto / Epic 模式补充
- `guides/*.md` — 复杂度、Review stage 执行、upstream-ref、upstream coverage 规则
- `prompts/*.md` — 各阶段 Review prompt
- `templates/*.md` — 编排产物模板
- `scripts/*.sh` — 机械校验脚本（`check-*.sh`）+ 工作目录初始化（`ensure-workdir-exclude.sh`）
