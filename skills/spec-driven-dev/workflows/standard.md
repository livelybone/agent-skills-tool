# Standard 模式工作流

Standard 模式负责编排完整流程，但在关键 gate 处等待人工确认。通用阶段顺序、stage key、role、artifact 路径、StageResult / ReviewResults 配对规则由 `SKILL.md` 的 Stage Registry 和「编排契约」定义；本文件只记录 Standard 模式差异。

## 模式语义

- Standard 不改变 13 步阶段顺序。
- Standard 在 Intake 阶段必须确认 `Worker Execution Policy` 与 `Review Runner Policy`。
- `Worker Execution Policy = subagent-allowed` 时，内容阶段按正常 Stage Worker 协议委派；`controller-only` 时，只能在本文件明确允许 inline 的场景内由 Controller 执行，否则停为 blocker 或升级给用户。
- `Review Runner Policy = cross-agent-allowed` 时，Review stage 可按 `guides/review.md` 启动 `multi-agent-loop`；`manual-only` 时，不得启动跨 agent runner。
- Standard 仍允许按 `guides/complexity.md` 合法跳过部分独立 Review runner；跳过必须基于复杂度和人工审查结论，而不是把缺少权限当成独立理由。
- Review Decision Gate 本身不可跳过；每个内容阶段完成后必须记录 `executed:<path>` 或 `skipped:<complexity + reason>`。
- 关键人工 gate 必须把用户裁决写入 `DecisionLog`，并把可续接事实并入 `WorkflowCheckpoint.Context Summary`。

## 内容阶段执行协议

内容阶段均遵循 `SKILL.md` 的 orchestration contract：Controller 写 `StageHandoff`，Stage Worker 产出 artifact + `StageResult`，Controller 读取二者判断 gate。

Clarify If Needed 是例外：Controller 直接与用户交互。用户回答后，简单澄清由 Controller inline 产出 `ClarifiedRequirement` + `StageResult`；复杂澄清在 `Worker Execution Policy = subagent-allowed` 时写 `StageHandoff` 委派 `requirements-clarification` subagent 整理，否则停为 blocker 或要求用户授权。

Inline 规则：Trivial 阶段可 inline，但必须满足三项留痕：Decision Log 写明 inline 原因、产出等价 `StageResult` 摘要、checkpoint 记录 artifact 与 stage result。Simple 阶段默认使用 Stage Worker；只有单问题澄清、无正式下游 artifact、且不会进入后续 worker 链路时才可 inline。Medium / Complex 阶段必须使用 Stage Worker；若 `Worker Execution Policy = controller-only` 或宿主平台没有可用 subagent，只能停为 blocker 或要求用户授权，不得静默降级为 Controller inline。

## 人工 Gate Overlay

| 阶段 key | Standard 人工 gate | 失败回退 |
|----------|--------------------|----------|
| `clarification` | 确认 `Goal / Actors / Trigger / In Scope / Out of Scope / Acceptance Signals` 足以支持建模 | 澄清结果改变主路径语义时，后续建模草稿失效 |
| `modeling` | 确认建模单元已就绪、未绕过 `modeling-first` 手编模型；若豁免，checkpoint 记录结构化 `modeling_exemption` | 模型缺项或聚合边界错误时，回到 `modeling-first` 并使下游 handoff 失效 |
| `plan` | Epic 时确认模块边界、依赖顺序、契约落位合理 | plan 变更模块边界或契约时，下游 tech spec / test / implementation handoff 失效 |
| `tech-spec` | 确认 TechnicalSpec 足以支持测试设计 | 需求语义问题回 clarification；模型缺口回 modeling；plan 边界问题回 plan |
| `test-design-and-implementation` | 确认关键规则、主流程、危险边界都被转换成测试约束，且 worker 内部已做自查 | 测试阶段暴露 spec 语义缺口时，回到 tech spec |
| `feature-implementation` | 确认交付与 scope 对齐，未偷偷扩写流程外语义 | spec / test / model 语义冲突时，回到最上游真实冲突点 |

## Review Decision Overlay

Review stage 的 runner、task-name、prompt、失败回退和 checkpoint 更新规则见 `guides/review.md`。Standard 允许按 `guides/complexity.md` 合法跳过部分独立 runner。

若 `Review Runner Policy = manual-only`，Controller 不得启动 `multi-agent-loop`；遇到复杂度规则要求强制执行的 Review（如 Modeling Exemption Review、Epic Plan Review）时，必须记录为 `blocked:<reason>` 或升级给用户，不得改写为 `skipped`。

合法跳过时必须同时：

- 在 Decision Log 写明 `跳过理由：<complexity 判定 + 具体理由>`。
- 在 `WorkflowCheckpoint.Review Results` 写成 `<checkpoint-key>: skipped:<complexity 判定 + 具体理由>`。
- 保持上一 content 阶段的 Context Summary 不丢失。

## Workflow Verification

由 Controller 执行：

1. 运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh` 对最终 Upstream Coverage Matrix 做机械校验（多单元场景按 `guides/upstream-coverage.md` 分别执行）。
2. 运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-review-results.sh --checkpoint <path>`，确认每个内容 stage（Clarification 除外）都有对应 `Review Results`。
3. 汇总当前状态、Review 执行/跳过理由、blockers / unfinished items / residual risks，以及下一次会话如何从 checkpoint 续接。

失败回退：

- Matrix exit 2 → 回到产生非法 upstream-ref 的阶段。
- Matrix exit 3 → 回到 `feature-implementation-from-spec`，补齐覆盖行或追加有效 NOT APPLICABLE 理由。
- Matrix exit 4 → 按位置失真所在列回到对应 worker（Spec / Test / Impl）。
- Matrix exit 5 → Controller 修复 matrix 文件本身。

## Decision Log 补充

Decision Log 字段见 `templates/decision-log.md`。Standard 模式特有补充：

- `模式` 字段写 `standard`。
- Intake 阶段必须记录用户选择的 `Worker Execution Policy` 与 `Review Runner Policy`；用户未明确回答时分别记录为 `controller-only` 和 `manual-only`。
- Review 阶段合法跳过时，`调用 worker / runner` 字段写 `skipped`，`结果` 字段写 `skipped`，`Context Summary 新增` 字段写 `无`。
- 所有人工 gate 的用户裁决必须记录；完成时用户应清楚 workflow 当前是 `done` 还是 `blocked`。
