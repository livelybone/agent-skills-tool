# 标准模式工作流

标准模式下，`spec-driven-dev` 负责编排完整流程，但在关键 gate 处等待人工确认。各阶段的详细内容规则由对应 worker skill 定义；本文件只定义 orchestrator 的阶段顺序、输入输出和回退点。

## 总流程

1. intake and route
2. clarify if needed
3. modeling
4. plan if epic
5. tech spec
6. test design and implementation
7. feature implementation
8. workflow verification and summary

每个阶段完成后都要：

- 更新 `WorkflowCheckpoint`
- 记录当前 blockers / open questions 摘要
- 明确下一个 worker 和 handoff 输入

## 步骤 0 — Intake And Route

- 判断需求是否模糊
- 判断是否为 Epic
- 判断当前 run 是 `standard` 还是 `auto`
- 若关键输入缺失且无法安全继续，先进入澄清阶段

## 步骤 1 — Clarify If Needed

- worker：`requirements-clarification`
- 输入：原始需求、已知约束、现有上下文
- 输出：`ClarifiedRequirement` 或显式 blocker

人工 gate：

- 确认 `Goal / Actors / Trigger / In Scope / Out of Scope / Acceptance Signals` 足以支持后续建模

回退：

- 若澄清结果改变了主路径语义，后续建模草稿失效

## 步骤 2 — Modeling

- worker：`modeling-first`
- 输入：原始需求或 `ClarifiedRequirement`
- 输出：`docs/models/<scenario>/<name>.md`，或经批准的 `modeling_exemption`

人工 gate：

- 确认需要的建模单元都已就绪
- 确认没有绕过 `modeling-first` 手编建模文件
- 建模审查：按 `guides/complexity.md` 的深度建议，决定是否追加独立审查（Medium/Complex 通常值得做，使用 `prompts/upstream-review.md`）
- 若本次走豁免：在 `WorkflowCheckpoint` 中记录结构化 `modeling_exemption`，并通过 `prompts/exemption-review.md` 完成独立审查或人工确认

回退：

- 若后续阶段发现模型缺项或聚合边界错误，回到此阶段修模并使下游 handoff 失效

## 步骤 3 — Plan If Epic

- 仅 Epic 执行
- 产物：`plan.md`
- 机械校验：`scripts/check-plan-structure.sh` + `scripts/check-upstream-coverage.sh`

人工 gate：

- 确认模块边界、依赖顺序、契约落位合理

回退：

- 若 plan 变更了模块边界或契约，后续 tech spec / test / implementation handoff 需要重建

## 步骤 4 — Tech Spec

- worker：`tech-spec-writing`
- 输入：requirement baseline + models（或已批准的 modeling exemption） + optional plan + optional review notes
- 输出：`TechnicalSpec`

人工 gate：

- 确认该模块的 technical spec 足以支持测试设计
- 按 `guides/complexity.md` 的深度建议，决定是否追加独立第二视角审查

回退：

- 若发现 blocker 来自需求语义，回退到 clarification
- 若发现 blocker 来自模型缺口，回退到 modeling
- 若发现 blocker 来自 plan 边界，回退到 plan

## 步骤 5 — Test Design And Implementation

- worker：`test-design-and-implementation`
- 输入：批准后的 `TechnicalSpec`
- 输出：场景稿 + 可执行测试

人工 gate：

- 确认关键规则、主流程、危险边界都被转换成测试约束
- 按 `guides/complexity.md` 的深度建议，决定是否追加独立审查

回退：

- 若测试阶段暴露 spec 语义缺口，回退到 tech spec

## 步骤 6 — Feature Implementation

- worker：`feature-implementation-from-spec`
- 输入：`TechnicalSpec` + `ExecutableTestSuite` + 相关模型约束
- 输出：`DeliveredChange`

人工 gate：

- 确认当前交付与 scope 对齐，未偷偷扩写流程外语义
- 按 `guides/complexity.md` 的深度建议，决定实现后是否追加更深复核

回退：

- 若实现阶段发现 spec / test / model 语义冲突，回退到最上游的真实冲突点

## 步骤 7 — Workflow Verification And Summary

由 orchestrator 执行：

1. 运行 `scripts/check-upstream-coverage.sh` 对最终 Upstream Coverage Matrix 做机械校验（多单元场景按 `guides/upstream-coverage.md` "Epic 多模块场景的调用方式" 分别执行）
2. 汇总：
   - 当前阶段是否已完成
   - 是否仍有 blockers / unfinished items / residual risks
   - 下一次会话如何从 checkpoint 续接

失败回退：

- Matrix 校验 exit 2（虚假 upstream-ref 或 `<doc>#<anchor>` 不存在）→ 回退到产生非法引用的阶段（Spec/Test/Impl 均可能），由对应 worker 修复
- Matrix 校验 exit 3（上游锚点未覆盖或 NOT APPLICABLE 理由缺失）→ 回退到 `feature-implementation-from-spec`，补齐覆盖行或追加有效 NOT APPLICABLE 理由
- Matrix 校验 exit 4（矩阵 Spec/Test/Impl 位置失真：无效行号、无效后缀、无效 symbol）→ 回退到该位置所属阶段的 worker（Spec 列失真 → `tech-spec-writing`；Test 列失真 → `test-design-and-implementation`；Impl 列失真 → `feature-implementation-from-spec`），修复矩阵行或源文件
- Matrix 校验 exit 5（matrix 文件 HTML 注释畸形）→ 由 orchestrator 修复 matrix 文件本身

标准模式的完成条件：

- 该 run 的 worker outputs 已按顺序产出
- Upstream Coverage Matrix 已产出并通过 `scripts/check-upstream-coverage.sh`
- `WorkflowCheckpoint` 已更新到最终状态
- 用户可以清楚知道 workflow 当前是 `done` 还是 `blocked`
