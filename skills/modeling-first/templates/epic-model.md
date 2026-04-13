# Epic Model — <Epic Name>

> 📖 **填写前必读**：
> - `../references/modeling-guide.md#step-a`（实体识别）
> - `../references/modeling-guide.md#step-a5`（聚合边界 3 个判定问题）
> - `../references/modeling-guide.md#invariant-scope`（跨聚合 vs 聚合内不变量）
> - `../references/modeling-guide.md#cross-aggregate-contract`（跨聚合契约线索格式）

**Context**: <一句话：Epic 的业务目标>
**Source**: <需求来源：PRD / brainstorming 产出 / 用户原话>
**Date**: YYYY-MM-DD
**Scope**: Epic 级轮廓建模；本文件 < 100 行；派生/模块内部不变量/具体 Reuse 留给各模块的 `model.md`

> **老项目引入新 Epic 时**：epic-model 只覆盖**本 Epic 引入或触及**的聚合；若某个既有聚合（未被本 Epic 修改）与本 Epic 有跨聚合关系，需在 Relationships 中体现该边界，但不必在 Entities 中重新展开其内部结构。

---

## 1. Entities（跨模块共享）

只列出**跨模块使用**或**属于本 Epic 核心领域**的实体。纯粹属于某个模块内部的实体不在此文件中展开。**每个实体必须带 `<!-- anchor: Entity.<Name> -->` 标记**。

<!-- anchor: Entity.Entity1 -->
- **`<Entity1>`** — 需求依据：`<原文引用 / 用户动作>` — 持有模块（初步）：`<module-name>` — 是否被其他模块引用：是/否

<!-- anchor: Entity.Entity2 -->
- **`<Entity2>`** — 需求依据：`<...>` — 持有模块：`<...>` — 被引用：是/否

> **持有模块**仅为初步标注，Plan 阶段会正式决定并填入 Plan 的"持有聚合"字段。

---

## 2. Relationships（跨模块 + 聚合边界）

关系决定模块边界和契约。

### 聚合清单

列出每个聚合及其根实体和内部实体。**每个聚合必须带 `<!-- anchor: Aggregate.<Name> -->` 标记**。一个聚合内部的实体一起读写、一起事务、一起存活。

**3 个判定口诀**（详见 `modeling-guide.md#step-a5`）：
1. "A 能脱离 B 存在吗？" 不能 → B 持有 A，同聚合
2. "查 A 总是要一起查 B 吗？" 是 → 同聚合
3. "改 A 和改 B 要在同一事务里吗？" 是 → 同聚合

<!-- anchor: Aggregate.Aggregate1 -->
- **`<Aggregate1>`** — 根实体：`<Root>` — 内部实体：`<Internal1, Internal2>`

<!-- anchor: Aggregate.Aggregate2 -->
- **`<Aggregate2>`** — 根实体：`<Root>` — 内部实体：`<Internal>`

**Plan 硬约束**：一个聚合内的实体不得跨模块。若 Plan 把同一聚合切散到两个模块，视为违反聚合边界，必须调整 Plan 或回修 epic-model。

### 跨聚合关系（将决定模块间契约）

**每条跨聚合关系必须带 `<!-- anchor: Rel.<A>-<B> -->` 标记**。"跨模块契约线索"用结构化格式（详见 `modeling-guide.md#cross-aggregate-contract`），不要写自由文字：

- `event: <EventName> from <producer> → <consumer>`
- `ref: <consumer> reads <Entity>.<field> from <producer>`
- `cmd: <caller> calls <Action>(<args>) on <target>`
- `snapshot: <consumer> persists <Entity> at <trigger>`

<!-- anchor: Rel.AggA-AggB -->
- **`<AggA> ↔ <AggB>`** — 基数：`<1:1 / 1:N / N:N>` — 语义：`<引用/包含/事件订阅等，删除语义>` — 契约：`<event: ... / ref: ... / cmd: ... / snapshot: ...>`

---

## 3. Shared Invariants（跨聚合/跨模块）

**只写跨聚合**的不变量；聚合内部不变量留给模块建模。**每条必须带 `<!-- anchor: SharedInvariant.<N> -->` 标记**。

**判定口诀**（详见 `modeling-guide.md#invariant-scope`）：只需读 1 个聚合即可校验 → 聚合内（不写这里）；必须读 ≥ 2 个聚合才能校验 → 跨聚合（写这里）。
- ✅ `Order.status='paid' → Payment.status='success'`（跨 Order + Payment）
- ❌ `Order.total >= 0`（只看 Order，属于聚合内，不应写这里）

<!-- anchor: SharedInvariant.1 -->
- `<跨聚合一致性约束，如：引用完整性、业务规则>`

<!-- anchor: SharedInvariant.2 -->
- `<合规/审计要求>`

若本 Epic 不存在跨聚合不变量，显式写：

<!-- anchor: SharedInvariant.none -->
- 无跨聚合不变量。理由：`<...>`

---

## 4. Aggregate → Module Mapping（可选，供 Plan 参考）

若已有 Plan 草稿，对照预期切分。Plan 阶段会基于此正式拆分并固化到 Plan 的"持有聚合"字段。

| 聚合 | 预期模块 | 备注 |
|------|---------|------|
| `<Aggregate>` | `<module>` | `<依赖提示>` |

---

## 5. Concept-Level Reuse（可选）

**概念层面**的复用提示，不做文件路径级搜索（那是模块建模的事）。

- `<如："项目已有 X 模块，本 Epic 的 Y 聚合应集成而非重建">`

---

## 6. Open Questions

- [ ] `<本 Epic 尚未决定的领域问题，如"匿名用户是否允许 X"、"实体 Y 是否独立聚合">`

---

## 7. Exposed Anchors（供下游引用的契约面）

本文件作为原子建模产物，只列出下游可通过 `upstream-ref` 引用的锚点命名空间。具体下游工作流（如 Plan/Spec/Test 编排、Review 规则、迭代回流）由调用方 skill 定义。

- `epic-model.md#Entity.<Name>` — 共享实体
- `epic-model.md#Aggregate.<Name>` — 聚合
- `epic-model.md#Rel.<A>-<B>` — 跨聚合关系 / 契约
- `epic-model.md#SharedInvariant.<N>` — 跨聚合不变量

---

<details>
<summary>📋 参考示例（电商订单支付场景，填写时请替换为当前 Epic 的真实内容）</summary>

```markdown
## 1. Entities
| User | "用户注册登录" | user 模块 | 是 |
| Order | "用户下单后可以取消" | order 模块 | 是 |
| Payment | "订单可以支付" | payment 模块 | 是 |

## 2. Relationships
### 聚合清单
| Order Aggregate | Order | OrderItem, OrderStatus |
| Payment Aggregate | Payment | PaymentTransaction |

### 跨聚合关系
| Order ↔ User | N:1 | Order 引用 User.id 不持有 | user 模块产出"用户匿名化事件"，order 模块消费 |
| Payment ↔ Order | 1:1 | Payment 引用 orderId | order 产出"订单完成事件"，payment 消费；payment 产出"支付成功事件"，order 消费 |

## 3. Shared Invariants
- Order.status = 'paid' → 必须存在 Payment.status = 'success'
- User.id 全局唯一
```

**注意**：上面是示例。本文件正文必须用**当前 Epic 的真实实体/关系**替换 `<...>` 占位符，不得留占位符或示例残留。

</details>
