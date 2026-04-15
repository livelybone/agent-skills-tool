# 跨模块建模规则

跨模块场景涉及两类规则：**跨模块不变量的放置**、**跨模块关系的契约格式**。

---

## 跨模块不变量的放置决策

<a id="cross-module-invariant"></a>

有些不变量需要读取多个模块的数据才能校验，例如 `Order.status='paid' → Payment.status='success'`（涉及 order 和 payment 两个模块）。这类不变量放在**执行者模块**。

### 执行者判定

"执行者" = 实际负责**校验并维护**这条不变量的模块。通常是：

- **状态转换的发起方**：例如订单从 pending → paid 由 order 模块触发，则 order 负责校验"paid 一定对应 success 支付"
- **关系的持有方**：例如 Favorite 持有 userId/articleId，由 favorite 模块维护"两者不能同时为空"
- **事件消费方**：例如 payment 产出 PaymentSucceeded 事件，order 消费并更新状态，那 order 是"paid → success"不变量的执行者

如果两个模块都合理，选与**业务规则变化频率**最高的一方（该不变量如果变，哪个模块最先改？）。

### 书写格式

在执行者建模单元（`docs/models/<scenario>/<name>.md`）的 Invariants 章节，显式标注 `[跨模块]` 前缀，并用 `upstream-ref` 引用涉及的其他单元的实体锚点。例：

```markdown
### 跨模块不变量

<!-- anchor: Invariant.Order.cross.1 -->
- **[跨模块]** `status === 'paid' → 存在对应的 Payment 且 Payment.status === 'success'`
  - 涉及：`upstream-ref: docs/models/domain/payments.md#Entity.Payment`
  - 执行者：本模块（order）在状态转换 paid 时校验
  - 失败处理：拒绝状态转换，抛业务异常
```

### 反例

- ❌ 把"User.email is unique"放跨模块章节（只看 user 模块就能校验，应放 user 模块的 Invariants）
- ❌ 把同一条跨模块不变量在 order 和 payment 两个模块都写一遍（应由执行者独占；另一方可以在 Relationships 里通过跨模块契约线索引用）

---

## 跨模块关系的契约线索

<a id="cross-module-contract"></a>

跨模块关系需用结构化格式描述契约，不要写自由文字：

| 契约类型 | 格式 | 例 |
|---------|------|-----|
| 事件（异步） | `event: <EventName> from <producer-module> → <consumer-module>` | `event: OrderCompleted from order → payment` |
| 引用（同步读） | `ref: <consumer-module> reads <Entity>.<field> from <producer-module>` | `ref: order reads User.id from user` |
| 命令（同步写） | `cmd: <caller-module> calls <Action>(<args>) on <target-module>` | `cmd: payment calls Refund(orderId) on order` |
| 快照 | `snapshot: <consumer> persists <Entity> at <trigger>` | `snapshot: order persists Coupon at checkout` |

一条跨模块关系可以同时列多个契约（如"订单完成触发事件 + 支付查询订单状态"）。

### 书写位置

跨模块关系写在**引用方单元**的 `docs/models/<scenario>/<name>.md` Relationships 章节的"跨单元关系"子节，通过 `upstream-ref` 指向被引用单元的实体。双向关系（A 引用 B + B 事件通知 A）可在两个单元中各自记录自己的那一半。
