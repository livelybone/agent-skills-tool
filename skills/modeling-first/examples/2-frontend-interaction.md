# 示例 2：前端交互建模（可拖拽看板）

**需求原文**：
> 实现一个项目看板，包含"待办"、"进行中"、"已完成"三个列，用户可以拖拽卡片在列之间移动。

**触发信号识别**：组件有多状态（拖拽状态机）+ 需求涉及多个视觉单元（卡片、列、看板）→ 文件级建模（full）

**归属单元**：`docs/models/ui/kanban.md`（UI 主导）

**建模文件**（示意）：

```md
**Unit**: `ui/kanban`
**Context**: 项目看板页面（三列拖拽）
**Source**: <需求来源>
**Date**: 2026-04-15

## Aggregates（本单元持有）
<!-- anchor: Aggregate.none -->
- 非 domain 单元，不持有业务聚合。卡片持久化由对应 domain 单元负责（如 `docs/models/domain/tasks.md`）。

## 1. Entities
（以下为 UI 视图模型，不是业务实体）

<!-- anchor: Entity.Board -->
- Board — 依据："项目看板" — 新建（UI 容器）
<!-- anchor: Entity.Column -->
- Column — 依据："待办/进行中/已完成三个列" — 新建
- Card — 依据："卡片" — `upstream-ref: docs/models/domain/tasks.md#Entity.Task` 的展示投影

## 2. Relationships
- Board → Column: 1:N, Board 持有 Column, 级联删
- Column → Card: 1:N, Column 持有 Card, 移动卡片 = 更换持有列

## 3. Derivation Chains
- Column.cardCount = count(cards where columnId = this.id)
- Card.position = sortIndex within column（拖拽后重新计算）

## 4. Invariants
- Board: columns.length >= 1（至少一列）
- Column: name in configured set（不允许用户自建列名）
- Card: 同一时刻只属于一个 Column
- Card: 拖拽中（dragging/over-column）时其他用户对同一卡片的操作应排队或冲突提示

## 5. Reuse Check
| 需要 | 已有 | 决策 |
|------|------|------|
| 拖拽库 | 项目的 drag-and-drop 依赖 | 复用或引入 |
| 排序逻辑 | 搜索后确认 | 决定 |

## 6. Open Questions
- [ ] 列名配置的来源（硬编码 / 管理端可配 / 项目级约定）？
- [ ] 拖拽冲突的具体处理策略（队列 / 最后写入胜出 / 提示重试）？

## State Machine — Card Drag（可选章节）
<!-- anchor: StateMachine.Card.Drag -->
States: idle | dragging | over-column | dropped
Transitions:
  idle → dragging       guard: mousedown on card    action: capture offset, create ghost
  dragging → over-column guard: enter column zone    action: show drop placeholder
  over-column → dragging guard: leave column zone    action: remove placeholder
  dragging → dropped     guard: mouseup             action: move card to target column, persist
  over-column → dropped  guard: mouseup in zone     action: move card to target column, persist
  dropped → idle         guard: animation done       action: remove ghost
```

**如何指导实现**：状态机直接对应拖拽 hook 的状态管理；Invariants 中的"同一时刻只属于一个 Column"防止实现时在拖拽中间态出现卡片同时存在于两列的 bug。
