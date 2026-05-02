# Decision Log 条目

Decision Log 记录每个内容、审查和编排阶段的流程决策。Standard、Auto 与 Epic workflow 共用本模板。

默认路径：`.spec-driven-dev/<run>/<module>/decision-log.md`。`<run>` 在 Epic 场景使用 Epic name，非 Epic 固定为 `single`；`<module>` 在 Epic 模块步骤使用 plan 模块名，Epic 级步骤使用 `_workflow`，非 Epic 固定为 `single`。

```markdown
### [阶段] 决策 #N

- 模式：<standard | auto>
- 当前阶段：<checkpoint key，如 payment/tech-spec / _workflow/plan>
- 阶段类型：content | review | orchestration
- Review stage key：<modeling-review / exemption-review / plan-review / spec-review / test-review / impl-review / N/A>
- 调用 worker / runner：<skill、runner 名、skipped 或 N/A>
- Handoff：<path 或 N/A>
- StageResult：<path 或 N/A>
- Review 轮次：<r1 / r2 / r3 或 N/A>
- 输入摘要：<关键输入>
- 结果：<完成 / skipped / 回退 / blocked / escalated>
- 关键 findings（Review 阶段）：<controller 裁决后的真 Critical/Major 条目摘要，或 N/A>
- Context Summary 新增：<本阶段并入 WorkflowCheckpoint.Context Summary 的关键信息；若无新增，写 无>
- 原因：<为什么>
- 后续动作：<next stage / retry / escalation / done>
```

`Context Summary` 是跨阶段累积的单一续接基线。每个阶段完成时必须把本阶段新增事实并入 `WorkflowCheckpoint.Context Summary`，并在本条 Decision Log 的「Context Summary 新增」字段留副本。
