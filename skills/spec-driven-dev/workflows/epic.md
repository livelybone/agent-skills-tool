# Epic 工作流

Epic 场景下，`spec-driven-dev` 先负责多单元建模和 plan，再按 plan 依赖顺序把每个模块路由到下游 worker stages。

## Epic 主路径

1. 多单元建模
2. 生成 `plan.md`
3. 机械校验 plan
4. 独立审查或人工确认 plan
5. 按 plan 顺序对每个模块执行：tech spec → test design and implementation → feature implementation
6. 汇总整个 Epic 的 workflow 状态

## 步骤 1 — 多单元建模

- 调用 `modeling-first` 识别所有受影响的 `docs/models/<scenario>/<name>.md`
- 先产出或更新建模单元，再进入 plan
- 不允许没有模型就直接切模块

## 步骤 2 — Plan

Plan 回答三个问题：

1. `What`：有哪些模块
2. `Order`：模块依赖顺序如何
3. `Contract`：模块间契约是什么

Plan 不回答实现细节；实现细节属于后续 worker 阶段。

## 步骤 3 — 机械校验

Plan 生成后必须通过：

- `scripts/check-plan-structure.sh`
- `scripts/check-upstream-coverage.sh`

未通过时，不允许继续路由下游 worker。

## 步骤 4 — Plan Review

Epic 中的 plan review 是最值得做独立第二视角的审查点，审查范围与判定口径见 `prompts/plan-review.md`。

- 标准模式：人工确认模块边界、依赖、契约（可选用 `prompts/plan-review.md` 作为 checklist 辅助）
- Auto 模式：必须通过 `multi-agent-loop` + `prompts/plan-review.md` 做独立 plan review，再由 controller 裁决

## 步骤 5 — 按模块路由后续 worker

对每个模块，`spec-driven-dev` 不自己生成 spec / tests / implementation，而是：

1. 组装该模块的 StageHandoff
2. 调用 `tech-spec-writing`
3. 调用 `test-design-and-implementation`
4. 调用 `feature-implementation-from-spec`
5. 更新该模块的 `WorkflowCheckpoint`

模块之间是否可并行，由 plan 的依赖关系决定；单个模块内部始终串行。

## Epic 回流规则

如果后续阶段发现上游边界错误，回流顺序如下：

- 模型错了 → 回到 modeling
- 模块边界或契约错了 → 回到 plan
- tech spec 错了 → 回到 tech spec stage
- tests 错了 → 回到 test stage

若 plan 被重开，则受影响模块的 downstream handoff 视为 stale，需要重新路由。

## Epic 完成条件

Epic workflow 完成时，应满足：

- 所有需要的建模单元已就绪
- `plan.md` 已通过校验
- 每个模块都已按顺序调用对应 worker
- 每个模块的 Upstream Coverage Matrix 已产出并通过 `scripts/check-upstream-coverage.sh`（多单元按 `guides/upstream-coverage.md` "Epic 多模块场景的调用方式" 分别校验）
- 每个模块的最终状态都能由 checkpoint 清晰说明
- orchestrator 能输出整个 Epic 当前是 `done`、`partially done` 还是 `blocked`
