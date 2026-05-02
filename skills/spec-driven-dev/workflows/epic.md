# Epic 工作流

Epic 场景下，`spec-driven-dev` 先负责多单元建模和 plan（含对应 Review），再按 plan 依赖顺序把每个模块独立跑完整的 tech-spec → test → implementation 序列。

通用阶段序列、内容阶段 handoff / result 契约、Review Decision Gate 由 `SKILL.md` 定义；Review stage 执行机制由 `guides/review.md` 定义。本文件只描述 Epic 特有的阶段组合方式、模块维度 task-name、并行约束、回流规则和 Decision Log 补充。

## Epic 主路径（沿用 13 步编号）

Epic 维度（只跑一次，对应 `SKILL.md` 的 13 步编号）：

```
3.  Multi-unit Modeling
4.  Modeling Review（或 Exemption Review）
5.  Plan If Epic + Mechanical Checks（check-plan-structure.sh + check-upstream-coverage.sh）
6.  Plan Review（Epic 强制）
```

模块维度（按 plan 依赖顺序，对每个模块依次跑）：

```
7.  Tech Spec（模块 M）
8.  Spec Review（模块 M）
9.  Test Design And Implementation（模块 M）
10. Test Review（模块 M）
11. Feature Implementation（模块 M）
12. Implementation Review（模块 M）
```

Epic 收尾（所有模块完成后跑一次）：

```
13. Workflow Verification And Summary（Epic）
```

## 步骤 3 — Multi-unit Modeling

- 调用 `modeling-first` 识别所有受影响的 `docs/models/<scenario>/<name>.md`
- 先产出或更新建模单元，再进入步骤 4 Modeling Review
- 不允许没有模型就直接切模块

## 步骤 4 — Modeling Review（Epic 维度）

- 执行：按 `guides/review.md` 的 `modeling-review` 配置审查本次产出或更新的**全部**建模单元
- 触发规则：按 `guides/complexity.md` 的表格「步骤 4 Modeling Review」行（auto 模式强制；standard 模式按 complexity）
- 若走建模豁免：改用 `guides/review.md` 的 `exemption-review` 配置（任意模式任意复杂度均强制）

## 步骤 5 — Plan

Plan 回答三个问题：

1. `What`：有哪些模块
2. `Order`：模块依赖顺序如何
3. `Contract`：模块间契约是什么

Plan 不回答实现细节；实现细节属于后续 worker 阶段。

Plan 产出后，orchestrator 也必须写一个 `StageResult`，并以 `_workflow/plan` key 登记到 `WorkflowCheckpoint.Stage Results`，用于和步骤 6 Plan Review 做机械配对。

## 步骤 5a — Mechanical Checks

Plan 生成后必须通过：

- `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-plan-structure.sh --plan <plan.md> --upstream <Epic 涉及的所有聚合来源单元>`
- `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh`（按 `guides/upstream-coverage.md` 的 Epic 多模块调用方式覆盖所有引用）

未通过时，不允许进入步骤 6。

## 步骤 6 — Plan Review（Epic 强制）

- 执行：按 `guides/review.md` 的 `plan-review` 配置启动独立审查
- Auto + Standard 两种模式下 Epic 场景**都强制执行**（Epic 的 Plan 是编排骨架，无法跳过）
- Complex Epic 建议多轮迭代（仍受 3 轮上限约束）

## 步骤 7-12 — Route Modules

对 plan 中的每个模块 M，按依赖顺序执行完整的内容 + Review 序列：

| 子步 | 阶段 | 执行规则 |
|------|------|---------|
| 7 | Tech Spec（M） | 写模块级 `StageHandoff`，stage worker 使用 `tech-spec-writing`；输入：该模块 plan 条目 + 模块涉及的建模单元；输出 TechnicalSpec + `StageResult` |
| 8 | Spec Review（M） | 按 `guides/review.md` 的 `spec-review` 配置执行；触发规则按模块复杂度字段（见 plan）决定是否执行 |
| 9 | Test Design & Implementation（M） | 写模块级 `StageHandoff`，stage worker 使用 `test-design-and-implementation`；输出测试产物 + Red Run + `StageResult` |
| 10 | Test Review（M） | 按 `guides/review.md` 的 `test-review` 配置执行；触发规则按模块复杂度 |
| 11 | Feature Implementation（M） | 写模块级 `StageHandoff`，stage worker 使用 `feature-implementation-from-spec`；输出 DeliveredChange + `StageResult` |
| 12 | Implementation Review（M） | 按 `guides/review.md` 的 `impl-review` 配置执行；触发规则按模块复杂度 |

模块内部**严格串行**：8 未收敛前不得进入 9；10 未收敛前不得进入 11；以此类推。

**模块之间**是否可并行，由 plan 的依赖关系决定：

- 无依赖的模块可并行启动（独立的 `WorkflowCheckpoint` + 独立的 `.agent-loop/<stage>-<module>/` 工作目录）
- 有依赖的模块必须等上游模块完成步骤 12 才能启动自己的步骤 7

Epic 下所有模块实现 artifacts 都必须落在 Epic name 目录下。推荐路径：`.spec-driven-dev/<EpicName>/<ModuleName>/<StepName>/handoff.md` 与 `.spec-driven-dev/<EpicName>/<ModuleName>/<StepName>/stage-result.md`。Epic 级步骤使用 `.spec-driven-dev/<EpicName>/_workflow/<StepName>/...`。

### Task-name 规范

Epic 场景下 Review task-name 必须带模块标识，以便多模块并行：

- `<stage>-<module>`；轮次只记录在 `.agent-loop/<task-name>/r<N>/` 和 checkpoint `round` 字段中
- 例：`spec-review-payment`、`impl-review-order`
- **禁止**跨模块复用同一 task-name（如 `spec-review`——会和其他模块冲突）

### 并行模块的约束

同一 orchestrator session 的工作上下文和 WorkflowCheckpoint 状态是共享的——无法为多个模块同时维护独立的 `Current Module` / `Context Summary`，宿主 harness 一旦压缩会同时影响所有在途模块。因此并行执行无依赖模块时，必须二选一：

- **方案 A（默认，推荐）**：同一 orchestrator session 内**串行**执行所有模块，即使 plan 允许并行。模块步骤使用 `.spec-driven-dev/<EpicName>/<ModuleName>/checkpoint.md`，Epic 级步骤使用 `.spec-driven-dev/<EpicName>/_workflow/checkpoint.md`
- **方案 B**：真正并行时，**每个并行模块启动独立的 orchestrator session**（如独立的 Claude Code 会话）。每个 session 只维护 `.spec-driven-dev/<EpicName>/<ModuleName>/checkpoint.md`，互不干扰
- **禁止**：同一 orchestrator session 内真正并行推进多模块——会造成模块间上下文互相覆盖

方案选择必须在 Decision Log 的 Plan Review 决策条目中显式记录（`并行策略: serial | multi-session`）。

## 步骤 13 — Workflow Verification And Summary

完成所有模块后，orchestrator 产出 Epic 级 workflow summary：

- 每个模块分别是 `done` / `partially-done` / `blocked`
- 每个模块的 Upstream Coverage Matrix 是否通过机械校验
- 每个模块的 Review 阶段轮数与关键裁决结果
- 整个 Epic 是否可以标记 `done`（所有模块 done 且所有 Matrix 通过）、`partially-done`（部分模块完成）还是 `blocked`

## Epic 回流规则

如果后续阶段发现上游边界错误，回流顺序如下：

- 模型错了 → 回到步骤 3，修模后重进步骤 4（Modeling Review）+ 可能触发步骤 6（Plan Review）重审
- 模块边界或契约错了 → 回到步骤 5，修 plan 后重进步骤 5a（机械校验）+ 步骤 6（Plan Review）
- 某模块的 tech spec 错了 → 该模块回到步骤 7 + 8
- 某模块的 tests 错了 → 该模块回到步骤 9 + 10
- 某模块的实现错了 → 该模块回到步骤 11 + 12

若 plan 被重开（步骤 5-6 重跑），所有下游模块的 handoff 视为 stale：

- 未开始的模块直接使用新 plan 重新启动
- 进行中的模块停在当前步骤，等新 plan 确认后判断是否需要回退到步骤 7

## Epic 完成条件

Epic workflow 完成时，应满足：

- 所有需要的建模单元已就绪且通过 Modeling Review（或 Exemption Review）
- `plan.md` 已通过机械校验 + Plan Review
- 每个模块都已按顺序调用对应 worker + 对应 Review
- 每个模块的内容阶段都有可定位的 `StageResult`
- 每个模块的 `WorkflowCheckpoint` 已通过 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-review-results.sh`
- 每个模块的 Upstream Coverage Matrix 已产出并通过 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh`（多单元按 `guides/upstream-coverage.md` "Epic 多模块场景的调用方式" 分别校验）
- 每个模块的最终状态都能由 checkpoint 清晰说明
- orchestrator 能输出整个 Epic 当前是 `done`、`partially-done` 还是 `blocked`

## 模式差异

Epic 场景继承 Standard / Auto 的通用模式语义；本节只列 Epic 特有差异：

- **Auto 模式**：步骤 4 / 6 / 8 / 10 / 12 全部强制执行，无人工 gate
- **Standard 模式**：
  - 步骤 4：分两种情形——若走正常建模，按 `guides/complexity.md`「步骤 4 Modeling Review」行判断是否执行；若走 `modeling_exemption`，**任意复杂度均强制执行** Exemption Review（不受 Epic 复杂度字段影响）
  - 步骤 6：任意复杂度均强制（Epic 的 Plan Review 是编排骨架，无法跳过）
  - 步骤 8 / 10 / 12：按 plan 中该模块的复杂度字段 + `guides/complexity.md` 对应行决定是否执行
  - 保留各 content 阶段人工 gate

## Decision Log 补充

Decision Log 字段见 `templates/decision-log.md`。Epic 特有补充：

- `当前阶段` 字段须使用 checkpoint key，形如 `<module>/tech-spec` / `<module>/test-design-and-implementation`
- Review 决策条目的 `当前阶段` 仍写被审查内容 key，并把具体 review stage 写入 `Review stage key`
- Epic 维度阶段（步骤 3–6 + 13）写 `当前阶段` 为 `_workflow/modeling` / `_workflow/plan` / `_workflow/epic-summary`
- 同一模块跨多轮 Review 时，task-name 保持 `<stage>-<module>`，按 `r1/r2/r3` 记轮次到 `Review 轮次` 字段
