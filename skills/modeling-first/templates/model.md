# Domain Model — <Feature Name>

> 📖 **填写前必读**：
> - `../references/modeling-guide.md#step-a`（实体识别）
> - `../references/modeling-guide.md#step-a5`（关系、基数、聚合边界）
> - `../references/modeling-guide.md#step-b`（派生关系）
> - `../references/modeling-guide.md#step-c`（不变量）
> - `../references/modeling-guide.md#anti-patterns`（反模式自查）

**Context**: <一句话：要做什么>
**Source**: <需求来源：brainstorming 产出路径 / 用户原话引用 / issue 链接>
**Date**: YYYY-MM-DD

---

## 1. Entities

列出领域实体。每条必须有需求依据（不是技术名词）。"位置"写实际项目语境下该实体最终会住在哪——可能是文件、模块、表、组件目录，不限制技术栈。

**每个实体必须带 `<!-- anchor: Entity.<Name> -->` 标记**，供下游 `upstream-ref` 引用。锚点命名：`Entity.<实体名>`，大小写敏感，跨文件全局唯一。

<!-- anchor: Entity.Order -->
- **Order** — 需求依据："用户下单后可以取消" — 新建（位置：`<按项目技术栈决定>`）

<!-- anchor: Entity.User -->
- **User** — 需求依据：已有 — 复用（位置：`<项目里已有的实际路径>`）

<!-- anchor: Entity.Coupon -->
- **Coupon** — 需求依据："订单可以使用优惠券抵扣" — 新建（位置：`<按项目技术栈决定>`）

> **不要抄示例**：填入时必须基于当前项目的目录约定和技术栈。实体名用领域语言，不用技术词。

---

## 2. Relationships

实体之间的关系。必须明确基数、所有权、聚合边界。漏掉关系 = 只是名词清单。

**每条关系必须带 `<!-- anchor: Rel.<A>-<B> -->` 标记**，锚点命名：`Rel.<EntityA>-<EntityB>`，顺序按所有权（持有方在前）。

<!-- anchor: Rel.Order-OrderItem -->
- **Order ↔ OrderItem** — 1:N — Order 持有 OrderItem — 级联（删订单同时删 items）

<!-- anchor: Rel.Order-User -->
- **Order ↔ User** — N:1 — User 被 Order 关联，User 不持有 Order — 保留（删用户不应删订单记录，应匿名化）

<!-- anchor: Rel.Order-Coupon -->
- **Order ↔ Coupon** — N:1 — Coupon 被引用，不被持有 — 保留（删券不影响历史订单的 snapshot）

---

## 3. Derivation Chains

**所有数值 / 时间 / 状态字段必须经过派生性审视**。写成等式，不接受"与 X 有关"。

### 根变量（调用方实际需要输入的）

- `Order.items: Item[]`
- `Order.couponId?: string`
- `Order.createdAt: DateTime`

### 派生值（不作为独立输入）

"派生位置"描述派生在哪里实现——**由项目技术栈决定**。**每条派生必须带 `<!-- anchor: Derivation.<Entity>.<field> -->` 标记**。

<!-- anchor: Derivation.Order.subtotal -->
- `Order.subtotal = sum(items[i].price * items[i].quantity for i in items)` — 派生位置：`<按项目技术栈决定>`

<!-- anchor: Derivation.Order.discount -->
- `Order.discount = if coupon exists then coupon.apply(subtotal) else 0` — 派生位置：`<按项目技术栈决定>`

<!-- anchor: Derivation.Order.total -->
- `Order.total = subtotal - discount` — 派生位置：`<按项目技术栈决定>`

<!-- anchor: Derivation.Order.expiresAt -->
- `Order.expiresAt = createdAt + ORDER_TTL` — 派生位置：`<按项目技术栈决定>`

> 等式用**伪代码**表达核心关系（不要照抄 TS/JS 语法），实际落地形态在实现阶段由技术栈确定。

**反例**（不要这么设计）：把 `subtotal`、`discount`、`total` 都作为独立字段存储/暴露——会出现"改一个漏另一个"。

---

## 4. Invariants

每个实体**至少一条**，或显式写明"**无不变量**"及理由。写成可验证条件（谓词），不要写"应该"、"一般"。**每条不变量必须带 `<!-- anchor: Invariant.<Entity>.<N> -->` 标记**（N 为该实体下的序号，从 1 开始）。

### Order

<!-- anchor: Invariant.Order.1 -->
- `total >= 0`

<!-- anchor: Invariant.Order.2 -->
- `items.length > 0`（空订单不允许创建）

<!-- anchor: Invariant.Order.3 -->
- `status in {'pending', 'paid', 'cancelled', 'expired'}`

<!-- anchor: Invariant.Order.4 -->
- `status === 'paid' → paidAt !== null`

<!-- anchor: Invariant.Order.5 -->
- `status === 'cancelled' → status 不能再变回 'paid'`（状态机约束）

### 例外示例：无不变量的实体（填写格式）

```
### AuditLog
<!-- anchor: Invariant.AuditLog.none -->
- **无不变量**。理由：纯追加型数据结构，不承载状态机或合法性约束；字段正确性由写入方保证。
```

### Coupon

<!-- anchor: Invariant.Coupon.1 -->
- `discount >= 0 && discount <= subtotal`（不能倒贴）

<!-- anchor: Invariant.Coupon.2 -->
- `validFrom <= validTo`

### User

<!-- anchor: Invariant.User.1 -->
- `email is unique`

<!-- anchor: Invariant.User.2 -->
- `email matches valid RFC 5322 format`

<!-- anchor: Invariant.User.3 -->
- `status in {'active', 'suspended', 'deleted'}`

---

## 5. Reuse Check

对每个实体、派生函数、工具逻辑，检索项目后填入实际路径（示例中的路径仅为结构示意，**不要抄用**）。

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 价格求和 | 无（已搜索 `<搜索条件>`） | 新建 `<按项目技术栈决定>` | - |
| 时间计算 | `<项目里已有的 date util 路径>` | 复用 | 签名匹配 |
| 金额格式化 | `<项目里已有的 money format 路径>` | 复用 | - |
| 状态机 | `<项目里已有的 state machine 路径>` | 扩展 | 已有通用实现，加订单 transition |
| 优惠券校验 | 无 | 新建 `<按项目技术栈决定>` | - |

**禁止**写"项目里可能有"、"应该有类似的"——必须实际搜索后填具体路径，或明确写"已搜索，未找到"。

---

## 6. Open Questions

无法独立决定的点，等待用户确认。不要强行给出结论。

- [ ] 优惠券和订单是 1:1 还是 1:N？（需求未明确）
- [ ] 订单过期后是否自动取消？TTL 多长？
- [ ] 是否需要部分退款？

---

<details>
<summary>📎 (可选) API Surface — 仅当模型暴露给调用方时填写，不占必填章节序号</summary>

用**伪代码**描述 API 形状——不要锁定到具体语言或范式。核心约束：**只暴露根变量 + 行为，不暴露派生值的 setter**。

伪代码示例：
```
// 构造：接收根变量
create(items, coupon?) → Order

// 读取：派生值只读
Order.subtotal → Money  (derived)
Order.total → Money     (derived)

// 行为：受不变量约束（cancel 不能让已 cancelled 的订单再变）
Order.cancel() → Order | Error
```

实际实现形态由项目技术栈决定（class / struct / trait / hook / REST API 等）。

</details>
