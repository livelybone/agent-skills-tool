# Plan — <Epic Name>

> 📖 **填写前必读**：
> - 本 Epic 的 `epic-model.md`（Epic 建模产出）
> - `workflows/epic.md`（Plan 格式、硬约束校验、回流规则）

**Context**: <一句话：Epic 的业务目标>
**Source**: <需求来源：PRD / brainstorming 产出 / issue 链接>
**Epic Model**: <建模文件路径，如 `docs/models/epic-model.md`>
**Date**: <YYYY-MM-DD>

---

## Module: <module-1-name>

- **持有聚合**：<聚合名> (upstream-ref: epic-model.md#Aggregate.<Name>)
- **边界**：<这个模块负责构建什么，一句话>
- **模块依赖**：无
- **产出契约**：<本模块暴露给下游的接口/能力> (upstream-ref: epic-model.md#Rel.<A>-<B>)
- **复杂度**：<Trivial / Simple / Medium / Complex>

## Module: <module-2-name>

- **持有聚合**：<聚合名> (upstream-ref: epic-model.md#Aggregate.<Name>)
- **边界**：<这个模块负责构建什么，一句话>
- **模块依赖**：<module-1> 的 <契约名> (upstream-ref: epic-model.md#Rel.<A>-<B>)
- **产出契约**：<...> (upstream-ref: epic-model.md#Rel.<C>-<D>)
- **复杂度**：<Trivial / Simple / Medium / Complex>

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
> - **步骤**：当前步骤编号 + 名称（如 `7 Test Implementation`）
> - **状态**：`pending` / `in_progress` / `done` / `blocked:<原因>`
> - **备注**：关键上下文（审查轮次、裁决数、阻塞原因等）
>
> 此表是新会话定位 Epic 宏观进度的入口。各模块的详细上下文（`context_summary`、`decision_log_ref`）在 `spec/<module>.md` frontmatter 中，续接时需先读此表定位模块，再读对应 spec frontmatter 恢复完整上下文（见 SKILL.md > 续接协议）。

---

## Plan 硬约束自检（生成后删除此节）

- [ ] 每个聚合有且仅出现在一个模块的"持有聚合"字段中
- [ ] 所有"模块依赖"和"产出契约"项能在 `epic-model.md` 的跨聚合关系中找到对应
- [ ] 每个模块的"持有聚合"指向 `epic-model.md` 中存在的聚合锚点
- [ ] 依赖关系图无循环
- [ ] 可并行的模块未被串行化
- [ ] Plan 不包含实现细节（协议格式、API 签名、状态机定义属于 Spec）

> 本节仅供自检，Plan Review 通过后应删除。
