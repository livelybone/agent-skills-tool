# Model — <scenario>/<name>

> **此文件存放路径**：`docs/models/<scenario>/<name>.md`（scenario 属 domain/ui/components/process/state-machine 五选一；name 用 kebab-case）。放置规则详见 `../SKILL.md#产物放置规则`。

> 📖 **填写前必读**：
> - `../SKILL.md#产物放置规则`（scenario 选择 / 路径命名 / Source of Truth）
> - `../references/steps/step-a.md`（实体识别）
> - `../references/steps/step-a5.md`（关系、基数、聚合边界）
> - `../references/cross-module.md`（跨模块关系格式 + 跨模块不变量放置，如适用）
> - `../references/steps/step-b.md`（派生关系）
> - `../references/steps/step-c.md`（不变量）
> - `../references/steps/step-d.md`（状态机建模，可选章节适用时）
> - `../references/steps/step-e.md`（流程建模，可选章节适用时）
> - `../references/steps/step-f.md`（组件识别，可选章节适用时）
> - `../references/anti-patterns.md`（反模式自查）

**Unit**: `<scenario>/<name>`（如 `domain/orders`、`ui/membership-center`、`components/overlay`）
**Context**: <一句话：本建模单元做什么>
**Source**: <需求来源：brainstorming 产出路径 / 用户原话引用 / issue 链接>
**Date**: YYYY-MM-DD

## Aggregates（本单元持有）

> 仅 `domain/` 单元必须填写聚合；`ui/` / `components/` / `process/` / `state-machine/` 单元写 `<!-- anchor: Aggregate.none -->` + 理由（"非 domain 单元，不持有业务聚合"）。

**一个 domain 单元可持有一个或多个聚合；一个聚合不得跨单元**。

<!-- anchor: Aggregate.Order -->
- **Order Aggregate** — 根实体：`Order` — 内部实体：`OrderItem`, `OrderStatus`

<!-- anchor: Aggregate.Coupon -->
- **Coupon Aggregate** — 根实体：`Coupon` — 内部实体：`CouponUsage`

---

## 1. Entities

列出领域实体。每条必须有需求依据（不是技术名词）。"位置"写实际项目语境下该实体最终会住在哪——可能是文件、模块、表、组件目录，不限制技术栈。

**每个实体必须带 `<!-- anchor: Entity.<Name> -->` 标记**，供下游 `upstream-ref` 引用。锚点命名：`Entity.<实体名>`，大小写敏感，**同一文件内唯一**（`upstream-ref: <file>#<Namespace>.<Name>` 以文件路径为作用域；不同文件中的实体可重名）。

> **跨 scenario 的 Source of Truth 约束**：业务实体只能在 `domain/` 单元定义；`ui/` 单元只能定义视图模型/展示投影（且命名不能与 `domain/` 已有实体重复——比如 `ui/orders.md` 可定义 `OrderSummary`，但不能重定义 `Order`）。详见 `../references/placement.md#source-of-truth-跨-scenario-规则`。

<!-- anchor: Entity.Order -->
- **Order** — 需求依据："用户下单后可以取消" — 新建（位置：`<按项目技术栈决定>`）

<!-- anchor: Entity.Coupon -->
- **Coupon** — 需求依据："订单可以使用优惠券抵扣" — 新建（位置：`<按项目技术栈决定>`）

**跨单元引用的实体**（不在本单元定义，通过 `upstream-ref` 引用其他单元）：

- **User** — `upstream-ref: docs/models/domain/users.md#Entity.User` — 本单元的 Order 通过 userId 关联 `domain/users` 的 User

> **填写指引**：基于当前项目的目录约定和技术栈填写；实体名用领域语言（订单、优惠券），避免技术词（接口、服务、控制器）。
> **跨模块引用**只写引用路径和本模块如何使用它，完整实体定义留在被引用文件中。

---

## 2. Relationships

实体之间的关系。必须明确基数、所有权、聚合边界。漏掉关系 = 只是名词清单。

**每条关系必须带 `<!-- anchor: Rel.<A>-<B> -->` 标记**，锚点命名：`Rel.<EntityA>-<EntityB>`，顺序按所有权（持有方在前）。

### 模块内关系

<!-- anchor: Rel.Order-OrderItem -->
- **Order ↔ OrderItem** — 1:N — Order 持有 OrderItem — 级联（删订单同时删 items）

<!-- anchor: Rel.Order-Coupon -->
- **Order ↔ Coupon** — N:1 — Coupon 被引用，不被持有 — 保留（删券不影响历史订单的 snapshot）

### 跨单元关系（契约线索）

跨单元关系需用结构化格式描述契约（详见 `../references/cross-module.md`）：

<!-- anchor: Rel.Order-User -->
- **Order ↔ `docs/models/domain/users.md#Entity.User`** — N:1 — User 被 Order 关联 — 保留（删用户不应删订单记录，应匿名化）
  - 契约：`ref: domain/orders reads User.id from domain/users`
  - 契约：`event: UserAnonymized from domain/users → domain/orders`（用户匿名化时 order 将 userId 置空）

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

### 视觉领域派生（如适用）

视觉属性间的联动也是派生关系，写在本章节中。如不涉及视觉属性，跳过本子节。

```
<!-- anchor: Derivation.Button.padding -->
- Button.padding = f(size)  — size='sm' → 4, 'md' → 8, 'lg' → 12
<!-- anchor: Derivation.Grid.columns -->
- Grid.columns = width >= 1200 ? 4 : width >= 768 ? 2 : 1
```

**反例**（不要这么设计）：把 `subtotal`、`discount`、`total` 都作为独立字段存储/暴露——会出现"改一个漏另一个"。

---

## 4. Invariants

每个实体**至少一条**，或显式写明"**无不变量**"及理由。写成可验证条件（谓词），不要写"应该"、"一般"。**每条不变量必须带 `<!-- anchor: Invariant.<Subject>.<N> -->` 标记**（N 为该 Subject 下的序号，从 1 开始）。

> `<Subject>` 在 `domain/` / `ui/` / `state-machine/` 单元中通常是实体名（`Entity.X` 对应 `Invariant.X.<N>`）；在 `process/` 单元中可以是 `Process` 或被引用的实体名；在 `components/` 单元中通常是组件名。详见 `../references/anchors.md`。

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

### 跨模块不变量（标注本模块为执行者时）

需要读取其他模块的数据才能校验的不变量，若本模块是执行者/维护者，写在本章节。

<!-- anchor: Invariant.Order.cross.1 -->
- **[跨模块]** `status === 'paid' → 存在对应的 Payment 且 Payment.status === 'success'`
  - 涉及：`upstream-ref: docs/models/domain/payments.md#Entity.Payment`
  - 执行者：本单元（domain/orders）在状态转换 paid 时校验
  - 失败处理：拒绝状态转换，抛业务异常

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
<summary>📎 (可选) State Machine — 实体或组件有多个离散状态时填写</summary>

> 📖 **填写前必读**：`../references/steps/step-d.md`

适用信号：UI 组件有多状态、业务对象有生命周期、交互流程有步骤序列。**每个状态机带 `<!-- anchor: StateMachine.<Entity>.<StateName> -->` 标记**（StateName 为状态机名称，如 `Drag`、`Approval`；单一状态机可省略 StateName 用实体名）。

<!-- anchor: StateMachine.Order -->
```
States: pending | paid | shipped | completed | cancelled
Transitions:
  pending → paid         guard: payment confirmed   action: record payment
  pending → cancelled    guard: user cancel / TTL   action: release inventory
  paid → shipped         guard: logistics confirmed action: send notification
  shipped → completed    guard: delivery confirmed  action: close order
```

每个可选章节 ≤ 30 行。

</details>

<details>
<summary>📎 (可选) Process Model — 涉及多步操作/条件分支/回滚时填写</summary>

> 📖 **填写前必读**：`../references/steps/step-e.md`

适用信号：多步审批、事务流程、向导型交互。**标记 `<!-- anchor: Process.<Name> -->`**。

<!-- anchor: Process.Checkout -->
```
Steps:
  1. validate_cart       → fail: return error
  2. reserve_stock       → fail: return error
  3. charge_payment      → fail: rollback(release_stock)
  4. create_order        → fail: rollback(refund, release_stock)
Concurrency: none
```

每个可选章节 ≤ 30 行。

</details>

<details>
<summary>📎 (可选) Component Identification — 本模块涉及多页面/多视图时填写</summary>

> 📖 **填写前必读**：`../references/steps/step-f.md`

适用信号：本模块涉及多个页面/视图，设计稿/需求中存在视觉重复。本章节在 Reuse Check **之前**填写。**标记 `<!-- anchor: Component.<Name> -->`**。

识别标准（满足任意两项）：视觉结构相同、交互模式相同、数据形状相同。

**放置决策**：
- 仅在本单元内部共享 → 写在本章节
- 跨单元共享的通用组件 → 放到 `docs/models/components/<family>.md`，本章节用 `upstream-ref` 引用
- 跨单元共享的业务组件 → 第一次使用就近放在本章节；第二次被使用时提升到 `docs/models/components/business-shared.md`（详见 `../references/placement.md#通用组件-vs-业务共用组件`）

### 单元内部共享

<!-- anchor: Component.OrderStatusCard -->
- **OrderStatusCard** — 出现位置：订单列表、订单详情页 — 输入：`order, actions`

### 跨单元共享（引用形式）

- `upstream-ref: docs/models/components/business-shared.md#Component.StatusCard` — 本单元作为消费方使用
- `upstream-ref: docs/models/components/overlay.md#Component.Modal` — 通用组件引用

每个可选章节 ≤ 30 行。

</details>

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
