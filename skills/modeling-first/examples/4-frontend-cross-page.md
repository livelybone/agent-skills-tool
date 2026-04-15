# 示例 4：前端跨页面建模（会员中心）

**需求原文**：
> 开发会员中心，包含订单列表页、收藏列表页、浏览历史页三个页面。

**触发信号识别**：需求涉及多个页面 + 页面间可能存在视觉重复 + 三个列表页有共享的筛选/分页/空状态逻辑 → 文件级建模（full）

**归属单元**：`docs/models/ui/membership-center.md`（UI 主导，前端应用模块）

**建模文件**（示意，突出跨页面维度）：

```md
**Unit**: `ui/membership-center`
**Context**: 会员中心三个列表页（订单/收藏/浏览历史）
**Source**: <需求来源>
**Date**: 2026-04-15

## Aggregates（本单元持有）
<!-- anchor: Aggregate.none -->
- 非 domain 单元，不持有业务聚合。相关数据归属 `domain/orders`、`domain/favorites`、`domain/browse-history`。

## 1. Entities
（以下为 UI 视图模型）

<!-- anchor: Entity.MembershipCenter -->
- MembershipCenter — 依据："会员中心" 容器 — 新建
<!-- anchor: Entity.OrderSummary -->
- OrderSummary — 依据："订单列表" 项 — `upstream-ref: docs/models/domain/orders.md#Entity.Order` 的展示投影
<!-- anchor: Entity.FavoriteItem -->
- FavoriteItem — 依据："收藏列表" 项 — 新建视图模型
<!-- anchor: Entity.BrowseHistoryItem -->
- BrowseHistoryItem — 依据："浏览历史" 项 — 新建视图模型

## 2. Relationships
- MembershipCenter → [OrderSummary | FavoriteItem | BrowseHistoryItem]: 1:N, 非持有（展示投影）
- 三种 Item 共享"时间倒序" 默认排序

## 3. Derivation Chains
（视觉领域派生）
- ListLayout.emptyState = items.length === 0 ? <EmptyState> : <ListView>
- Pagination.hasMore = loadedCount < totalCount

## 4. Invariants
- 每页默认按最近时间倒序
- 未登录用户不能访问任何页（统一在路由层拦截，不在各页重复处理）

## Component Identification（可选，跨页面扫描产出）
识别标准：视觉结构相同 + 交互模式相同 → 合并为共享组件。

<!-- anchor: Component.ListPageShell -->
- **ListPageShell** — 出现位置：订单/收藏/历史三页
  输入：title, items, renderItem, emptyState, onLoadMore
  职责：分页滚动、空状态、加载中、错误态统一处理

<!-- anchor: Component.TimestampedListItem -->
- **TimestampedListItem** — 出现位置：订单/收藏/历史三页
  输入：title, subtitle?, timestamp, thumbnail?, actions?
  职责：统一的"时间戳 + 标题 + 缩略图 + 操作"布局

<!-- anchor: Component.ListFilterBar -->
- **ListFilterBar** — 出现位置：订单/收藏两页（历史页暂无）
  输入：filters, activeFilter, onChange
  职责：水平 Tab 切换筛选

## 5. Reuse Check
| 需要 | 已有 | 决策 |
|------|------|------|
| 分页列表 | <搜索后确认> | 复用或扩展 |
| 路由守卫 | <auth 模块> | 复用 |
| 空状态 | <existing EmptyState> | 复用 |

## 6. Open Questions
- [ ] 浏览历史的保留期限？超期自动清理还是手动？
- [ ] 三页是否共享一套数据获取 hook（如 `useListWithPagination`）？
```

**如何指导实现**：组件识别章节直接产出三个共享组件的清单和输入接口，强制 coding-agent 实现时**先做共享组件**再做各页面，防止"逐页实现 → 各自写一套列表容器"这种反模式 5 行为。Invariants 中的"路由层拦截"阻止 coding-agent 在三页都重复写登录检查逻辑。
