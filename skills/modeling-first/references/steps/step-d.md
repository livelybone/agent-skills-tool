# Step D: 识别状态机（适用时）

**触发信号**：实体或组件有多个离散状态，且状态间转换受条件约束。典型场景：

- UI 组件：按钮（idle / hover / active / disabled / loading）、模态框（closed / opening / open / closing）
- 业务对象：订单（pending → paid → shipped → completed）、审批（draft → submitted → approved / rejected）
- 交互流程：多步表单（step1 → step2 → step3 → submitted）、拖拽（idle → dragging → hovering → dropped）

**产出格式**（四要素）：

- **States**：所有合法状态的枚举
- **Transitions**：`from → to` 的转换列表
- **Guards**：每个转换的前置条件（什么时候**允许**转换）
- **Actions**：每个转换触发的副作用（转换时**做什么**）

```
States: idle | dragging | hovering | dropped
Transitions:
  idle → dragging       guard: mousedown on item    action: capture offset, add drag style
  dragging → hovering   guard: enter drop zone      action: show drop indicator
  hovering → dragging   guard: leave drop zone      action: hide drop indicator
  dragging → dropped    guard: mouseup              action: reorder items, persist
  hovering → dropped    guard: mouseup in zone      action: reorder items, persist
  dropped → idle        guard: animation complete   action: remove drag style
```

**与实体-关系四件套的配合**：状态机建模补充 Invariants 中的状态转换约束。如果实体已有状态枚举和转换规则，状态机建模将其结构化为完整的 states/transitions/guards/actions，而非重复定义。
