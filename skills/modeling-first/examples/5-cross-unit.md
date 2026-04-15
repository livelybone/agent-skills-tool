# 示例 5：跨单元建模（新需求触及多个单元）

**需求原文**：
> 订单系统已上线。现在引入退款：用户申请退款 → 管理员审批 → 审批通过后调支付网关退款 → 完成后更新订单状态。还要新建一个管理员退款审批页面。

**触发信号识别**：
- 引入新业务实体（RefundRequest）+ 触及已有 `domain/orders` + `domain/payments` → 跨单元建模
- 新建管理员审批页面 → 新增 `ui/refunds` 单元
- 建模单元清单：
  - 新建 `docs/models/domain/refunds.md`（持有 RefundRequest Aggregate）
  - 增量 `docs/models/domain/orders.md`（新增跨单元关系 + 状态转换）
  - 增量 `docs/models/domain/payments.md`（新增退款 cmd/event）
  - 新建 `docs/models/ui/refunds.md`（管理员审批页面）

**docs/models/domain/refunds.md**（新建）：

```md
**Unit**: `domain/refunds`

## Aggregates（本单元持有）
<!-- anchor: Aggregate.RefundRequest -->
- RefundRequest Aggregate — 根：RefundRequest — 内部：ApprovalStep

## 1. Entities
<!-- anchor: Entity.RefundRequest -->
- RefundRequest — 依据："用户申请退款" — 新建
<!-- anchor: Entity.ApprovalStep -->
- ApprovalStep — 依据："管理员审批" 引入（RefundRequest 聚合内部实体）— 新建

## 2. Relationships
### 跨单元关系
<!-- anchor: Rel.RefundRequest-Order -->
- RefundRequest ↔ `docs/models/domain/orders.md#Entity.Order` — N:1 — Order 被引用
  - 契约：`ref: domain/refunds reads Order.status, Order.amount from domain/orders`
  - 契约：`event: RefundApproved from domain/refunds → domain/orders`（审批通过、开始走打款，orders 据此进入 refunding）
  - 契约：`event: RefundCompleted from domain/refunds → domain/orders`（退款完成，orders 据此进入 refunded）
  - 契约：`event: RefundFailed from domain/refunds → domain/orders`（退款失败，orders 据此 refunding → paid，等待人工后续处理）

<!-- anchor: Rel.RefundRequest-Payment -->
- RefundRequest ↔ `docs/models/domain/payments.md#Entity.Payment` — N:1
  - 契约：`cmd: domain/refunds calls Refund(paymentId, amount) on domain/payments`
  - 契约：`event: PaymentRefunded from domain/payments → domain/refunds`（payments 退款成功，refunds 据此 refunding → completed 并向 orders 发 RefundCompleted）
  - 契约：`event: PaymentRefundFailed from domain/payments → domain/refunds`（payments 退款失败，refunds 据此 refunding → failed 并向 orders 发 RefundFailed）

## 4. Invariants
### 跨模块不变量
<!-- anchor: Invariant.RefundRequest.cross.1 -->
- **[跨模块]** RefundRequest.amount <= Order.paidAmount
  - 涉及：`upstream-ref: docs/models/domain/orders.md#Entity.Order`
  - 执行者：本单元（domain/refunds）创建 RefundRequest 时校验

<!-- anchor: Invariant.RefundRequest.cross.2 -->
- **[跨模块]** 发往 `domain/orders` 的事件序列必须保序：`RefundApproved` 必须先于同一 RefundRequest 的 `RefundCompleted` / `RefundFailed` 到达 orders
  - 涉及：`upstream-ref: docs/models/domain/orders.md#StateMachine.Order`
  - 执行者：本单元（domain/refunds）按"先 emit RefundApproved 并等待事件总线投递成功的 ack（即总线持久化收据），再 call cmd Refund on payments"的顺序触发；事件总线必须按 producer FIFO 投递（从而保证 orders 端的消费顺序也是 FIFO）
  - **ack 边界定义**：仅指事件总线返回的"已持久化、保证按序投递"的收据，**不**等待 orders 完成消费；orders 端按总线 FIFO 顺序消费即可保序
  - 失败处理：若 RefundApproved 投递 ack 未返回（超时或拒绝），整个 transition 回滚（refunds 保持 pending），不得调用 payments cmd

## State Machine — RefundRequest（业务状态机）
<!-- anchor: StateMachine.RefundRequest -->
States: pending | refunding | completed | failed | rejected
Transitions:
  pending → refunding     guard: admin approve            action: 1) emit RefundApproved → domain/orders 并等待事件总线投递 ack；2) call cmd Refund(paymentId, amount) on domain/payments（顺序与 ack 边界见 Invariant.RefundRequest.cross.2）
  pending → rejected      guard: admin reject             action: notify user
  refunding → completed   guard: PaymentRefunded event from domain/payments  action: emit RefundCompleted → domain/orders；notify user
  refunding → failed      guard: PaymentRefundFailed event                   action: emit RefundFailed → domain/orders；notify admin（人工处理）
```

**docs/models/domain/orders.md 增量**（追加，不删除已有锚点）：

```md
## 2. Relationships
### 跨单元关系（新增）
<!-- anchor: Rel.Order-RefundRequest -->
- Order ↔ `docs/models/domain/refunds.md#Entity.RefundRequest` — 1:N
  - 契约：`event: RefundApproved from domain/refunds → domain/orders`（orders 消费，进入 refunding）
  - 契约：`event: RefundCompleted from domain/refunds → domain/orders`（orders 消费，进入 refunded）
  - 契约：`event: RefundFailed from domain/refunds → domain/orders`（orders 消费，回到 paid）

## State Machine — Order（增量）
增加状态：refunding, refunded
Transitions 新增：
  paid → refunding        guard: RefundApproved event    action: mark refunding
  refunding → refunded    guard: RefundCompleted event   action: mark refunded
  refunding → paid        guard: RefundFailed event      action: 恢复 paid 状态，等待人工后续处理
```

**docs/models/domain/payments.md 增量**（追加 Refund cmd 支持）：

```md
## Process Model — Refund（新增）
<!-- anchor: Process.Refund -->
Steps:
  1. validate_paymentId  → fail: emit PaymentRefundFailed event → domain/refunds
  2. call_gateway_refund → fail: mark failed, emit PaymentRefundFailed event → domain/refunds
  3. emit PaymentRefunded event → domain/refunds
```

**docs/models/ui/refunds.md**（新建）：

```md
**Unit**: `ui/refunds`

## 1. Entities
### 视图模型
<!-- anchor: Entity.RefundApprovalCard -->
- RefundApprovalCard — 审批列表项，从 `domain/refunds` 投影展示

### 跨单元引用
- RefundRequest — `upstream-ref: docs/models/domain/refunds.md#Entity.RefundRequest`
- Order — `upstream-ref: docs/models/domain/orders.md#Entity.Order`

## State Machine — RefundApprovalPage（UI 层）
<!-- anchor: StateMachine.RefundApprovalPage -->
States: list | approving | approved | rejected
Transitions:
  list → approving        guard: click approve item
  approving → approved    guard: confirm + cmd success
  approving → rejected    guard: reject with reason
```

**如何指导实现**：
1. `domain/refunds` 是退款业务的**执行者单元**，持有核心不变量（业务 Source of Truth）
2. 与 `domain/orders` / `domain/payments` 的所有交互通过**契约线索**明确表达（ref / cmd / event），防止实现时随意跨边界调用
3. `domain/orders` 和 `domain/payments` 的已有锚点**不变**，只做增量追加（新增关系、新增状态、新增 Process）
4. `ui/refunds` 作为前端单元独立演化，通过 `upstream-ref` 引用 domain 层实体，不重定义
5. 跨单元视图通过读上述 4 个 md 文件拼起来
6. 每个单元路径清晰按 `docs/models/<scenario>/<name>.md`，不混放
