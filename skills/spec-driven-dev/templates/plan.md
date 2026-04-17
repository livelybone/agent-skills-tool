# Plan — <Epic Name>

> 📖 **填写前必读**：
> - 本 Epic 涉及的所有建模单元（`docs/models/<scenario>/<name>.md`，由 `modeling-first` v0.3+ 产出）
> - `workflows/epic.md`（Plan 格式、硬约束校验、回流规则）
> - `guides/upstream-ref.md`（upstream-ref 语法、路径约束、按 scenario 划分的命名空间）

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

## Dependency Graph

```
<module-1>（无依赖）
  ↓
<module-2>（依赖 module-1）
                              <module-3>（并行于 module-2，无依赖）
```

---

## Progress

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
> 此表是新会话定位 Epic 宏观进度的入口。各模块的详细上下文由 orchestrator 的 `WorkflowCheckpoint` 维护；**Auto 与 Standard 模式共用**编排级 `Decision Log`（字段定义见 `workflows/auto.md` 的「Decision Log 字段」节），在会话或临时目录中维护，不持久化到仓库。续接协议见 SKILL.md。

---

## Plan 硬约束自检（生成后删除此节）

- [ ] 每个聚合有且仅出现在一个模块的"持有聚合"字段中
- [ ] 所有"模块依赖"和"产出契约"项能在某 `domain/<name>.md` 或 `process/<name>.md` 的 `Rel.*` 锚点中找到对应（Rel 位于引用方单元）
- [ ] 每个模块的"持有聚合"指向对应 `domain/<name>.md` 中存在的 `Aggregate.*` 锚点
- [ ] 所有 upstream-ref 的路径都以 `<scenario>/<name>.md` 结尾（scenario ∈ {domain, ui, components, process, state-machine}）
- [ ] 跨模块不变量（`Invariant.*.cross.*`）的执行者归属清晰（每条在唯一模块中执行）
- [ ] 依赖关系图无循环
- [ ] 可并行的模块未被串行化
- [ ] Plan 不包含实现细节（协议格式、API 签名、状态机定义属于 Spec）
- [ ] 机械校验通过：`scripts/check-plan-structure.sh --plan plan.md --upstream <Epic 涉及的所有 domain/*.md 以及包含 Aggregate.* 的其他单元>` 与 `scripts/check-upstream-coverage.sh`（覆盖所有引用的建模单元）均 exit 0。`--upstream` 是 Epic 场景硬性要求，**语义是"Epic 涉及的所有聚合来源单元"而非仅"Plan 引用的单元"**——必须包含尚未被 Plan 引用的 domain 单元，否则"整个单元的聚合都未被持有"的失配会漏检

> 本节仅供自检，Plan Review 通过后应删除。
