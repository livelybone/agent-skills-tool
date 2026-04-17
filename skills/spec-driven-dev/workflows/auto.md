# Auto 模式工作流

Auto 模式是 `spec-driven-dev` 的**自动编排模式**。

它的含义是：由 orchestrator 自动调用各阶段 worker，并在普通 stage gate 之间自动推进；不是 orchestrator 自己替代 worker 生成阶段内容。

## 核心语义

- `--auto` 仍表示自动推进模式
- 各阶段正式产物仍由对应 worker skill 生成
- orchestrator 负责自动路由、检查 gate、维护 Decision Log / workflow summary
- 只有触发升级边界时才暂停给用户

## Auto 模式阶段序列

1. intake and route
2. clarify if needed
3. modeling
4. plan if epic
5. tech spec
6. test design and implementation
7. feature implementation
8. workflow verification and summary

## Auto 模式下 orchestrator 的职责

### 1. 自动路由 worker

- 需求不清晰时自动调用 `requirements-clarification`
- 默认调用 `modeling-first`；仅在建模豁免成立且已记录到 `WorkflowCheckpoint` 时跳过
- Epic 自动产出并校验 `plan`
- 按顺序调用 `tech-spec-writing` → `test-design-and-implementation` → `feature-implementation-from-spec`

### 2. 自动维护编排级记录

- `Decision Log`：记录 stage routing、关键裁决、回退原因、审查降级、blockers
- `WorkflowCheckpoint`：记录当前阶段、上一步完成情况、context summary
- `workflow summary`：流程结束时面向用户的汇总，不替代 worker 自己的正式交付物
- 最终 verification 阶段自动运行 `scripts/check-upstream-coverage.sh` 校验 Matrix；失败分流规则同 `workflows/standard.md` 步骤 7

### 3. 自动触发独立审查

- **建模审查（强制）**：`modeling-first` 产出建模单元后，必须通过 `prompts/upstream-review.md` 做独立审查，承担命名空间合法性与领域对齐兜底（见 `guides/upstream-ref.md`）
- **建模豁免审查（条件强制）**：若使用 modeling exemption，必须通过 `prompts/exemption-review.md` 完成独立审查
- **Plan Review（Epic 强制）**：Epic 场景下的 plan review 必须通过 `prompts/plan-review.md` 做独立审查
- 其他阶段是否需要独立第二视角，跟随 worker skill 自身规则或当前风险判断
- 独立审查必须通过 `multi-agent-loop` 执行，默认优先使用 `opencode`

## 禁止行为

- 不得因为 `--auto` 就跳过 worker stage
- 不得把 worker 模板直接复制回 orchestrator 中维护
- 不得在未生成阶段正式产物时伪造“已完成”状态
- 不得以“上下文太长”为由暂停普通流程；应先写 checkpoint 再继续

## 升级边界

以下情况必须停止自动推进并升级给用户：

- 需求语义本身存在冲突
- 建模或 plan 需要超出当前权限的边界调整
- worker 返回的 blocker 会改变后续阶段的核心行为
- 独立审查出现无法自主裁决的结论冲突
- 关键 worker 或审查 runner 出现不可恢复的技术故障

## 审查与降级

- 独立审查 runner 不可用时，先在同一 runner 上至少重试一次
- 仍失败则升级给用户，不得私自改成同进程自审
- 如用户授权切换 runner 或接受降级，记录到 `Decision Log`

## Auto 模式完成条件

Auto run 完成时，用户应能看到：

- 本次 workflow 经过了哪些阶段
- 哪些阶段成功完成、哪些阶段被阻塞
- 当前最终交付物是什么（通常是 `DeliveredChange` 或显式 blocker）
- Upstream Coverage Matrix（已通过 `scripts/check-upstream-coverage.sh`）
- 还剩哪些 residual risks / unfinished items

## Decision Log 建议字段

```markdown
### [阶段] 决策 #N

- 模式：auto
- 当前阶段：<stage>
- 调用 worker：<skill>
- 输入摘要：<关键输入>
- 结果：<完成 / 回退 / blocked>
- 原因：<为什么>
- 后续动作：<next stage or escalation>
```
