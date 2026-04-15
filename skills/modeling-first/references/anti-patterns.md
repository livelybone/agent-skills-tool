# 反模式（模式匹配的典型产物）

完成建模后对照此清单自查。每次建模至少扫一遍这 7 条。

## 反模式 1: 派生值被当独立输入（含 UI props、API 参数、配置项）

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

## 反模式 2: 三件套目录

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

## 反模式 3: 数据结构模仿实现

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

## 反模式 4: 平行新建

```
// ❌ 项目里已有通用日期工具，但新功能重新写了一个，导致两套实现并存
<features/orders/utils/date-helper>   ← 新建
  addDays(date, days)

<utils/date>                           ← 已有
  addDuration(date, duration)
```

根因是没有做 Reuse Check。模式匹配模式会直接写新的，建模模式会先搜索已有表达并复用/扩展。

## 反模式 5: 跨页面组件重复实现

```
// ❌ 设计稿中"订单列表页"和"退款列表页"用了同一个 StatusCard 组件
// 但 coding-agent 逐页实现，各自写了一套
pages/orders/OrderStatusCard     ← 实现 A
pages/refunds/RefundStatusCard   ← 实现 B（布局相同，仅文案不同）

// ✅ 建模阶段识别出共享组件，实现一次，两处引用
components/StatusCard            ← 共享组件
pages/orders/OrderList           ← 引用 StatusCard
pages/refunds/RefundList         ← 引用 StatusCard
```

这是反模式 4（平行新建）在前端的具体表现。根因是 coding-agent 逐页面处理，缺少跨页面的组件识别步骤（Step F）。

## 反模式 6: 列表页模板化铺设

```
// ❌ coding-agent 看到"N 个列表页" → 套"列表页通用模板" → 逐页复制
pages/
  orders/
    OrderListPage       ← 分页 + 筛选 + 空状态 + 时间戳布局，全都本地实现
  favorites/
    FavoriteListPage    ← 同上，但"只是改了数据源和字段名"
  history/
    HistoryListPage     ← 同上

// 结果：三份几乎一模一样的分页/空状态/加载态代码，只有数据源不同

// ✅ 建模识别出"列表页"本身是一种可抽象的 Shell 模式
components/
  ListPageShell         ← 分页、空状态、加载中、错误态，一次实现
  TimestampedListItem   ← 列表项的通用布局

pages/orders/OrderListPage     ← 传入数据源和 itemRenderer，<30 行
pages/favorites/FavoriteListPage
pages/history/HistoryListPage
```

根因：coding-agent 没有在多页场景下做横向扫描，而是把"列表页"当成一个独立实体逐个实现。与反模式 5（跨页面组件重复）并列，但层级更高——反模式 5 关注细粒度组件（StatusCard 等），本反模式关注页面级容器。防御方法：组件识别（Step F）不仅要识别"列表项"，还要识别"列表页 Shell"本身。

## 反模式 7: 假建模

```md
<!-- ❌ 看起来像建模，其实是凑字数 -->
## Entities
- Order: 订单实体，包含订单的所有信息
- User: 用户实体，包含用户的所有信息
```

没有需求依据、没有派生关系、没有不变量——就是把需求里的名词抄一遍。这种"建模"对 LLM 写代码时没有任何约束作用。
