# 标准模式工作流

标准模式下，`spec-driven-dev` 负责编排完整流程，但在关键 gate 处等待人工确认。各阶段的详细内容规则由对应 worker skill 定义；本文件只定义 orchestrator 的阶段顺序、输入输出、Review 触发规则和回退点。

Review 阶段的执行机制、角色、task-name、裁决规则与 `workflows/auto.md` 的「每个 Review 阶段的统一协议」完全一致；两种模式的**唯一差异**是：是否强制执行。

每个 Review 阶段在该统一协议表中包含六项关键字段：`stage key / prompt / 被审查产物 / runner / task-name 规范 / 失败回退到`。本文件各步骤只补 `stage key / prompt / 失败回退 / 触发规则 / 跳过规则` 与 Standard 模式相关的部分，其余字段一律指向 auto.md 的统一协议表——**读者必须两份一起读**才能得到 Standard 模式下某 Review 阶段的完整执行规则。

- **Auto 模式**：每个 Review 阶段强制执行
- **Standard 模式**：Review 阶段**是否执行**按 `guides/complexity.md` 的复杂度判断，允许跳过，跳过必须在 Decision Log 中留痕

## 13 步阶段序列

```
1.  Intake And Route
2.  Clarify If Needed
3.  Modeling
4.  Modeling Review               ← 按 complexity.md 触发
    (或 Modeling Exemption Review ← 走豁免时，条件强制)
5.  Plan If Epic
6.  Plan Review (Epic only)       ← Epic 强制，Medium/Complex 建议多轮
7.  Tech Spec
8.  Spec Review                   ← 按 complexity.md 触发
9.  Test Design And Implementation
10. Test Review                   ← 按 complexity.md 触发
11. Feature Implementation
12. Implementation Review         ← 按 complexity.md 触发
13. Workflow Verification And Summary
```

每个阶段完成后都要：

- 把本阶段新增的关键信息并入 `Context Summary`，更新并落盘 `WorkflowCheckpoint`
- 记录当前 blockers / open questions 摘要
- 明确下一个 worker（或 Review runner）和 handoff 输入

Review 收敛后的 Checkpoint 更新规则与 `workflows/auto.md` 的「Review 收敛后的 Checkpoint 更新」节一致。Standard 模式下若某 Review 被合法跳过（complexity 档位允许），跳过事实在 Decision Log 留痕；上一 content 阶段的新增已在该 content 阶段完成时并入 Summary，跳过 Review 不影响续接基线。

## 步骤 1 — Intake And Route

- 判断需求是否模糊
- 判断是否为 Epic
- 判断当前 run 是 `standard` 还是 `auto`
- 若关键输入缺失且无法安全继续，先进入澄清阶段

## 步骤 2 — Clarify If Needed

- worker：`requirements-clarification`
- 输入：原始需求、已知约束、现有上下文
- 输出：`ClarifiedRequirement` 或显式 blocker

人工 gate：

- 确认 `Goal / Actors / Trigger / In Scope / Out of Scope / Acceptance Signals` 足以支持后续建模

回退：

- 若澄清结果改变了主路径语义，后续建模草稿失效

## 步骤 3 — Modeling

- worker：`modeling-first`
- 输入：原始需求或 `ClarifiedRequirement`
- 输出：`docs/models/<scenario>/<name>.md`，或经批准的 `modeling_exemption`

人工 gate：

- 确认需要的建模单元都已就绪
- 确认没有绕过 `modeling-first` 手编建模文件
- 若走豁免：在 `WorkflowCheckpoint` 中记录结构化 `modeling_exemption`

回退：

- 若后续阶段发现模型缺项或聚合边界错误，回到此阶段修模并使下游 handoff 失效

## 步骤 4 — Modeling Review

- stage key：`modeling-review`
- prompt：`prompts/upstream-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」表
- 触发规则：按 `guides/complexity.md` 的表格「步骤 4 Modeling Review」行
- 失败回退：同 `workflows/auto.md` 步骤 4 的回退规则
- 跳过规则：允许跳过的复杂度档位按 complexity.md；跳过时必须在 Decision Log 中留痕

### 步骤 4' — Modeling Exemption Review（走豁免时条件强制）

- stage key：`exemption-review`
- prompt：`prompts/exemption-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」表
- 触发规则：按 `guides/complexity.md` 的表格「步骤 4' Modeling Exemption Review」行（任意复杂度均强制）
- 失败回退：同 `workflows/auto.md` 步骤 4' 的回退规则

## 步骤 5 — Plan If Epic

- 仅 Epic 执行
- 产物：`plan.md`
- 机械校验：`scripts/check-plan-structure.sh` + `scripts/check-upstream-coverage.sh`

人工 gate：

- 确认模块边界、依赖顺序、契约落位合理

回退：

- 若 plan 变更了模块边界或契约，后续 tech spec / test / implementation handoff 需要重建

## 步骤 6 — Plan Review（Epic 强制）

- stage key：`plan-review`
- prompt：`prompts/plan-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」表
- 触发规则：按 `guides/complexity.md` 的表格「步骤 6 Plan Review」行（Epic 任意复杂度均强制；Complex Epic 建议多轮，仍受 `multi-agent-loop` 3 轮上限约束）
- 失败回退：同 `workflows/auto.md` 步骤 6 的回退规则

## 步骤 7 — Tech Spec

- worker：`tech-spec-writing`
- 输入：requirement baseline + models（或已批准的 modeling exemption） + optional plan + optional review notes
- 输出：`TechnicalSpec`

人工 gate：

- 确认该模块的 technical spec 足以支持测试设计

回退：

- 若发现 blocker 来自需求语义，回退到 clarification
- 若发现 blocker 来自模型缺口，回退到 modeling
- 若发现 blocker 来自 plan 边界，回退到 plan

## 步骤 8 — Spec Review

- stage key：`spec-review`
- prompt：`prompts/spec-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」表
- 触发规则：按 `guides/complexity.md` 的表格「步骤 8 Spec Review」行
- 失败回退：同 `workflows/auto.md` 步骤 8 的回退规则
- 跳过规则：允许跳过的复杂度档位按 complexity.md；跳过时必须在 Decision Log 留痕

## 步骤 9 — Test Design And Implementation

- worker：`test-design-and-implementation`
- 输入：批准后的 `TechnicalSpec`
- 输出：场景稿 + 可执行测试 + Red Run 结果

人工 gate：

- 确认关键规则、主流程、危险边界都被转换成测试约束
- worker 内部已做 `scenario-review` + `test-review` 两次自查

回退：

- 若测试阶段暴露 spec 语义缺口，回退到 tech spec

## 步骤 10 — Test Review

- stage key：`test-review`
- prompt：`prompts/test-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」表
- 触发规则：按 `guides/complexity.md` 的表格「步骤 10 Test Review」行
- 失败回退：同 `workflows/auto.md` 步骤 10 的回退规则
- 跳过规则：允许跳过的复杂度档位按 complexity.md；跳过时必须在 Decision Log 留痕

## 步骤 11 — Feature Implementation

- worker：`feature-implementation-from-spec`
- 输入：`TechnicalSpec` + `ExecutableTestSuite` + 相关模型约束
- 输出：`DeliveredChange`

人工 gate：

- 确认当前交付与 scope 对齐，未偷偷扩写流程外语义

回退：

- 若实现阶段发现 spec / test / model 语义冲突，回退到最上游的真实冲突点

## 步骤 12 — Implementation Review

- stage key：`impl-review`
- prompt：`prompts/impl-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」表
- 触发规则：按 `guides/complexity.md` 的表格「步骤 12 Implementation Review」行
- 失败回退：同 `workflows/auto.md` 步骤 12 的回退规则
- 跳过规则：允许跳过的复杂度档位按 complexity.md；跳过时必须在 Decision Log 留痕

## 步骤 13 — Workflow Verification And Summary

由 orchestrator 执行：

1. 运行 `scripts/check-upstream-coverage.sh` 对最终 Upstream Coverage Matrix 做机械校验（多单元场景按 `guides/upstream-coverage.md` "Epic 多模块场景的调用方式" 分别执行）
2. 汇总：
   - 当前阶段是否已完成
   - 每个 Review 阶段是否执行，若跳过则跳过理由
   - 是否仍有 blockers / unfinished items / residual risks
   - 下一次会话如何从 checkpoint 续接

失败回退：

- Matrix 校验 exit 2（虚假 upstream-ref 或 `<doc>#<anchor>` 不存在）→ 回退到产生非法引用的阶段（Spec/Test/Impl 均可能），由对应 worker 修复
- Matrix 校验 exit 3（上游锚点未覆盖或 NOT APPLICABLE 理由缺失）→ 回退到 `feature-implementation-from-spec`，补齐覆盖行或追加有效 NOT APPLICABLE 理由
- Matrix 校验 exit 4（矩阵 Spec/Test/Impl 位置失真：无效行号、无效后缀、无效 symbol）→ 回退到该位置所属阶段的 worker（Spec 列失真 → `tech-spec-writing`；Test 列失真 → `test-design-and-implementation`；Impl 列失真 → `feature-implementation-from-spec`），修复矩阵行或源文件
- Matrix 校验 exit 5（matrix 文件 HTML 注释畸形）→ 由 orchestrator 修复 matrix 文件本身

标准模式的完成条件：

- 该 run 的 worker outputs 已按顺序产出
- 每个应执行的 Review 阶段都有结论（执行或明确跳过）
- Upstream Coverage Matrix 已产出并通过 `scripts/check-upstream-coverage.sh`
- `WorkflowCheckpoint` 已更新到最终状态
- 用户可以清楚知道 workflow 当前是 `done` 还是 `blocked`

## Decision Log 字段

Standard 模式的 Decision Log 字段与 `workflows/auto.md` 的「Decision Log 字段」节**完全共用**。本文件不复述字段列表。

Standard 模式特有补充（不在 auto.md 中定义的）：

- `模式` 字段写 `standard`
- **Review 阶段合法跳过时**，额外记一行 `跳过理由：<complexity 判定 + 具体理由>`，同时 `调用 worker / runner` 字段写 `skipped`，`结果` 字段写 `skipped`，`Context Summary 新增` 字段写 `无`
