# Plan — <Epic 名称>

> 📖 **填写前必读**：
> - 本 Epic 涉及的所有建模单元（`docs/models/<scenario>/<name>.md`，由 `modeling-first` v0.3+ 产出）
> - `workflows/epic.md`（Plan 格式、硬约束校验、回流规则）
> - `guides/upstream-ref.md`（upstream-ref 语法、路径约束；命名空间权威见 `modeling-first/references/anchors.md`）

**Context**: <一句话：Epic 的业务目标>
**Source**: <需求来源：PRD / brainstorming 产出 / issue 链接>
**Modeling Units**: <本 Epic 涉及的建模单元清单，例如：>
- `docs/models/domain/order.md`
- `docs/models/domain/payment.md`
- `docs/models/ui/order-dashboard.md`
- `docs/models/process/refund.md`

**Date**: <YYYY-MM-DD>

---

## Module: <module-1-name>

- **持有聚合**：<聚合名> (upstream-ref: docs/models/domain/<name>.md#Aggregate.<Name>)
- **边界**：<这个模块负责构建什么，一句话>
- **模块依赖**：无
- **产出契约**：<本模块暴露给下游的接口/能力> (upstream-ref: docs/models/domain/<name>.md#Rel.<A>-<B>)
- **复杂度**：<Trivial / Simple / Medium / Complex>

## Module: <module-2-name>

- **持有聚合**：<聚合名> (upstream-ref: docs/models/domain/<name>.md#Aggregate.<Name>)
- **边界**：<这个模块负责构建什么，一句话>
- **模块依赖**：<module-1> 的 <契约名> (upstream-ref: docs/models/domain/<module-1-domain>.md#Rel.<A>-<B>)
- **产出契约**：<...> (upstream-ref: docs/models/domain/<name>.md#Rel.<C>-<D>)
- **复杂度**：<Trivial / Simple / Medium / Complex>

> **路径说明**：`upstream-ref` 既可写完整路径 `docs/models/<scenario>/<name>.md#<anchor>`，也可只写 scenario-qualified 短路径 `<scenario>/<name>.md#<anchor>`——`check-upstream-coverage.sh` 通过最后两段路径匹配身份。Rel 锚点位于**引用方**单元（通常是 `domain/<name>.md`，流程主导的跨模块关系可以是 `process/<name>.md`；契约线索格式与归属规则见 `modeling-first/references/cross-module.md`）。

---

## 依赖图

```
<module-1>（无依赖）
  ↓
<module-2>（依赖 module-1）
                              <module-3>（并行于 module-2，无依赖）
```

---

## 进度

| 模块 | 步骤 | 状态 | 备注 |
|------|------|------|------|
| <module-1> | — | pending | |
| <module-2> | — | pending | 依赖 module-1 |
| <module-3> | — | pending | |

> **更新规则**：每个模块的每个步骤完成后，立即更新对应行的"步骤"和"状态"列。
> - **步骤**：当前 orchestration 阶段（如 `tech-spec`、`test-design-and-implementation`、`feature-implementation`）
> - **状态**：`pending` / `in_progress` / `done` / `partially-done` / `blocked:<原因>`
> - **备注**：关键上下文（审查轮次、裁决数、阻塞原因等）
>
> 此表是新会话定位 Epic 宏观进度的入口。各模块的详细上下文由 orchestrator 的 `WorkflowCheckpoint` 维护；编排级 `Decision Log` 字段见 `templates/decision-log.md`。

---

## 校验 Gate

生成后必须通过 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-plan-structure.sh --plan plan.md --upstream <Epic 涉及的所有聚合来源单元>`、`$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh` 和 Plan Review。详细规则由脚本与 `prompts/plan-review.md` 维护。
