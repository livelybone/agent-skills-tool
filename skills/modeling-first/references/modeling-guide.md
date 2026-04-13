# Modeling Guide — 建模方法与反模式

## 为什么要建模（背景）

LLM 实现需求时有两种默认模式：

- **模式匹配**（默认）：看到需求 → 检索训练数据中相似问题的代码模板 → 产出
- **建模**（需要引导）：看到需求 → 识别领域实体与关系 → 从模型派生实现

模式匹配的问题：
- 同一逻辑在多处被不同方式重新实现（LLM 不记得上次写过什么）
- 把样式/配置字段全暴露为 props（模板里见到的就是这样）
- 在已有抽象旁平行新建相似概念（不做 reuse check）

建模把 LLM 从第一种模式切到第二种，这就是本 skill 的目的。

---

## 核心方法：三步建模

<a id="step-a"></a>
### Step A: 识别实体（名词法）

1. 读需求原文，把所有名词圈出来
2. 分类：
   - **领域名词**（保留）：订单、用户、权限、优惠券
   - **技术名词**（去掉）：接口、页面、组件、服务
   - **容器名词**（合并）：列表、表格、集合 → 归入对应实体的复数
3. 检查隐含名词：用户动作的宾语是否引入了新实体？例如"用户可以收藏商品" → 引入 `Favorite`

**识别信号**：如果一个概念有**生命周期**（创建、修改、删除）或**身份**（可以区分两个实例），它就是实体。

<a id="step-a5"></a>
### Step A.5: 识别实体间关系（基数 + 所有权 + 聚合边界）

列完实体后，立刻处理它们之间的关系。不做这一步，产出只是名词清单。

- **基数**：1:1 / 1:N / N:N
- **所有权**：上下游关系。订单持有订单项（订单删则订单项删），但用户不持有订单（用户删不应删订单历史）
- **聚合边界**：事务一致性和删除语义的边界。同一聚合内部保证事务一致，跨聚合只保证最终一致

**识别信号**：
- 问"A 能脱离 B 存在吗？" — 不能 → B 持有 A，删 B 时 A 跟着删
- 问"查 A 总是要一起查 B 吗？" — 是 → 同一聚合
- 问"改 A 和改 B 需要在同一事务里吗？" — 是 → 同一聚合

<a id="step-b"></a>
### Step B: 识别派生关系（问三个问题）

对每个字段问：

1. **"这个值是调用方主动输入的，还是我能从别的值算出来？"**
   - 能算出来 → 派生值，不应作为独立输入
2. **"如果有两个字段，调用方只改了其中一个，会不会出现不一致？"**
   - 会 → 它们之间有派生关系，应只暴露根变量
3. **"这个字段的值范围由什么决定？"**
   - 由另一个字段决定 → 派生或约束关系

**典型派生模式**：

| 类别 | 例子 |
|------|------|
| 几何派生 | `borderRadius = height / 2`, `width = height * aspectRatio` |
| 聚合派生 | `total = sum(items.price * items.quantity)` |
| 时间派生 | `expiresAt = createdAt + TTL`, `age = now - birthDate` |
| 状态派生 | `isExpired = now > expiresAt`, `canCancel = status === 'pending'` |
| 逻辑派生 | `hasDiscount = coupon !== null && coupon.valid` |

<a id="step-c"></a>
### Step C: 识别不变量（问两个问题）

对每个实体问：

1. **"什么状态是非法的？"**
   - 例：`total < 0` 非法 → 不变量：`total >= 0`
2. **"状态之间的转换有什么约束？"**
   - 例：已取消的订单不能重新支付 → 不变量：`cancelled → !paid`

**原则**：每个实体至少一条不变量。若实体真的没有任何状态/合法性约束（例如纯追加型 `AuditLog`、仅作为数据载体的 DTO），必须在该实体下显式写"**无不变量**"并给出理由，而不是省略。完全省略 = 没做这一步。

**不变量的价值**：
- 决定 API 设计（派生值不暴露 setter）
- 决定测试用例（每个不变量至少一条测试）
- 决定错误处理（违反不变量时的行为）

---

<a id="anti-patterns"></a>
## 反模式（模式匹配的典型产物）

### 反模式 1: 派生值被当独立输入（含 UI props、API 参数、配置项）

```
// ❌ 模式匹配的产物：把一堆本应派生的值当独立输入
Button(height=40, borderRadius=20, paddingHorizontal=16, paddingVertical=8, minHeight=40, iconSize=20)

// ✅ 建模后：只暴露根变量 size，其余值内部派生
Button(size='md')
  where borderRadius = height / 2
        padding     = f(size)
        iconSize    = f(size)
```

同一反模式也适用于：API 同时接收 `startDate`、`endDate`、`duration`（只需任意两个）；配置同时暴露 `retryCount`、`baseDelay`、`totalTimeout`（后者可派生）。**本模式不特指某个技术栈**。

### 反模式 2: 三件套目录

```
// ❌ 模式匹配产物（在训练数据里见过无数次）
services/
  OrderService
  OrderManager
  OrderHandler
  OrderController
  OrderHelper

// ✅ 建模后：一个实体的行为和不变量聚在一处（形态由项目技术栈决定）
<project-specific location>
  Order {
    data: ...
    behaviors: create / cancel / pay
    invariants: ...
  }
```

三件套/四件套/五件套通常说明没有领域模型，只是按技术职责切分空壳。**关键是一个实体的行为和不变量聚在一处，而不是散落在 N 个空壳里**——具体落成 class、struct、module 还是 package 由技术栈决定。

### 反模式 3: 数据结构模仿实现

```
// ❌ 模仿了 "后端响应长什么样" 而不是 "领域长什么样"
Order {
  order_id: string
  order_status_code: number  // 1/2/3/4 对应什么？
  order_price_total: number
  order_price_subtotal: number
  order_price_discount: number
}

// ✅ 建模：status 是枚举，price 字段大多是派生（以伪代码表达，实际形态由技术栈决定）
Order {
  id: OrderId
  items: OrderItem[]
  status: 'pending' | 'paid' | 'cancelled' | 'expired'
  subtotal → Money  (derived)
  total → Money     (derived)
}
```

模型只约束"**派生值不作为独立存储/输入**"，不规定实现形态——具体可以是计算属性、方法、视图、memo 等，由项目技术栈决定。

### 反模式 4: 平行新建

```
// ❌ 项目里已有通用日期工具，但新功能重新写了一个，导致两套实现并存
<features/orders/utils/date-helper>   ← 新建
  addDays(date, days)

<utils/date>                           ← 已有
  addDuration(date, duration)
```

这是因为没有做 Reuse Check。模式匹配模式会直接写新的，建模模式会先搜索已有表达并复用/扩展。

### 反模式 5: 假建模

```md
<!-- ❌ 看起来像建模，其实是凑字数 -->
## Entities
- Order: 订单实体，包含订单的所有信息
- User: 用户实体，包含用户的所有信息
```

没有需求依据、没有派生关系、没有不变量——就是把需求里的名词抄一遍。这种"建模"对 LLM 写代码时没有任何约束作用。

---

<a id="invariant-scope"></a>
## 不变量的作用域：跨聚合 vs 聚合内（仅轮廓模式需要区分）

轮廓模式只记录**跨聚合**不变量，聚合内的留给模块级建模。判定方法：

**只需一个聚合的状态即可校验** → 聚合内（不写进 `epic-model.md`）
- `Order.total >= 0`（只看 Order 聚合）
- `Order.items.length > 0`（只看 Order 聚合）
- `User.email is unique`（只看 User 聚合）

**需要跨两个或更多聚合的状态才能校验** → 跨聚合（写在 `epic-model.md` 的 Shared Invariants 章节，锚点 `epic-model.md#SharedInvariant.<N>`）
- `Order.status='paid' → 必须存在对应的 Payment.status='success'`（涉及 Order + Payment 两个聚合）
- `User.id 被删除后，Order.userId 必须变 null 或匿名化`（涉及 User + Order）
- `同一 Coupon 不能在两个不同 Order 上同时处于"已使用"状态`（涉及 Coupon + Order 集合）

**判定口诀**：能用"单个聚合的当前数据"判定的 → 聚合内；必须"至少读两个聚合的数据"才能判定的 → 跨聚合。

---

<a id="cross-aggregate-contract"></a>
## 跨聚合契约线索的填写格式（epic-model.md 用）

`epic-model.md` 的跨聚合关系需要填"契约线索"。用下列结构化格式，不要写自由文字：

| 契约类型 | 格式 | 例 |
|---------|------|-----|
| 事件（异步） | `event: <EventName> from <producer-module> → <consumer-module>` | `event: OrderCompleted from order → payment` |
| 引用（同步读） | `ref: <consumer-module> reads <Entity>.<field> from <producer-module>` | `ref: order reads User.id from user` |
| 命令（同步写） | `cmd: <caller-module> calls <Action>(<args>) on <target-module>` | `cmd: payment calls Refund(orderId) on order` |
| 快照 | `snapshot: <consumer> persists <Entity> at <trigger>` | `snapshot: order persists Coupon at checkout` |

一条跨聚合关系可以同时列多个契约（如"订单完成触发事件 + 支付查询订单状态"）。

---

## 识别"需要建模"的信号

明显需要建模：
- 需求中出现 ≥ 2 个新领域概念
- 需求涉及状态变化（"用户下单后..."、"订单支付后..."）
- 需求涉及计算（价格、评分、进度、剩余时间）
- 需求涉及约束（"不能超过"、"必须"、"最多"）
- 需求涉及跨模块协作（订单 × 支付 × 通知）

明显不需要建模（跳过本 skill）：
- "把按钮颜色改成蓝色"
- "修一下 API 调用的 bug"
- "把这个函数改成 async"
- "补一个单元测试"
- "升级依赖版本"

介于之间（问用户）：
- 功能看起来简单但涉及多个模块
- 看似小改动但动到了核心抽象

---

## 与其他 skill 的衔接

### 来自 brainstorming

brainstorming 产出是**需求探索结果**（要做什么、为什么做、不做什么）。modeling-first 消费它的"要做什么"部分，转化为领域模型。

### 交给 spec-driven-dev

spec-driven-dev 需要明确的需求和边界才能写出好的 Spec。`model.md` 提供的实体、不变量、派生关系是 Spec 场景和测试用例的直接来源。

- 每条不变量 → 至少一条单元测试
- 每个派生关系 → 一条 property-based test（根变量变，派生值也跟着变）
- 每个状态转换 → 一条场景测试

### 触发 code-review

如果 code-review skill 检测到违反**模式 5（冗余实体）**或**模式 6（未派生值）**：

- 反向检查：这个功能当初有没有走 modeling-first？
- 没走 → 补建模，再重构
- 走了但被违反 → 说明模型没被遵守，修复实现使其对齐模型

---

## 最小性原则

本 skill 的产出 **< 150 行**。超出说明：

- 把不确定的东西写进来了（应该放 Open Questions）
- 模仿 DDD/UML 写了过多抽象（本 skill 不是 DDD）
- 描述性文字多于结构化信息

建模不是写文档的艺术，是让 LLM 切换思维模式的最小契约。

---

## 一个完整示例（精简版）

**需求原文**：
> 用户可以把文章加入收藏。收藏列表按收藏时间倒序。用户取消登录后，匿名设备的收藏保留 7 天。

**model.md**（精简；`<位置>` 由项目技术栈决定，下面不预设）：

```md
## Entities
| 实体 | 依据 | 位置 |
|------|------|------|
| Article | "文章" | 复用（项目现有路径） |
| Favorite | "加入收藏" 动作引入 | 新建 |
| AnonymousSession | "匿名设备" | 新建 |

## Relationships
- Favorite ↔ Article: N:1, Article 不持有 Favorite, 删 Article 时 Favorite 孤立 (需清理)
- Favorite ↔ User: N:1, 删 User 级联删 Favorite
- Favorite ↔ AnonymousSession: N:1, 会话过期后 Favorite 按 TTL 过期

## Derivation Chains
- `Favorite.displayOrder = -favoritedAt.timestamp`（倒序）
- `Favorite.expiresAt = session.anonymous ? favoritedAt + 7d : null`

## Invariants
- Article: **无不变量**（此处的 Article 是被引用方，不因本功能引入新约束）
- Favorite: `userId != null XOR sessionId != null`（要么归属用户要么归属匿名会话）
- Favorite: `expiresAt === null → user.isAuthenticated`
- AnonymousSession: `createdAt + maxLifetime >= now`（过期会话不应继续存在）

## Reuse Check
| 需要 | 已有（搜索后确认） | 决策 |
|------|------------------|------|
| 会话管理 | `auth/session.*`（项目实际路径） | 扩展：加 anonymous 字段 |
| 时间 TTL | 项目里的 date util | 复用 |

## Open Questions
- 登录后匿名收藏是否迁移到用户账户？
```

这个模型约 25 行，但 Spec 阶段几乎可以直接从它推出所有测试场景。
