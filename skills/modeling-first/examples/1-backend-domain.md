# 示例 1：后端领域建模（收藏功能）

**需求原文**：
> 用户可以把文章加入收藏。收藏列表按收藏时间倒序。用户取消登录后，匿名设备的收藏保留 7 天。

**归属单元**：`docs/models/domain/favorites.md`（后端领域主导）

**建模文件**（示意，省略了锚点和部分细节）：

```md
**Unit**: `domain/favorites`
**Context**: 实现文章收藏与匿名设备收藏过期
**Source**: <需求来源>
**Date**: 2026-04-15

## Aggregates（本单元持有）
<!-- anchor: Aggregate.Favorite -->
- Favorite Aggregate — 根：Favorite
<!-- anchor: Aggregate.AnonymousSession -->
- AnonymousSession Aggregate — 根：AnonymousSession

## 1. Entities

- Article — 依据："文章" — `upstream-ref: docs/models/domain/articles.md#Entity.Article`
<!-- anchor: Entity.Favorite -->
- Favorite — 依据："加入收藏" 动作引入 — 新建
<!-- anchor: Entity.AnonymousSession -->
- AnonymousSession — 依据："匿名设备" — 新建

## 2. Relationships
- Favorite ↔ Article: N:1, Article 不持有 Favorite, 删 Article 时 Favorite 孤立 (需清理)
- Favorite ↔ User: N:1, 删 User 级联删 Favorite
- Favorite ↔ AnonymousSession: N:1, 会话过期后 Favorite 按 TTL 过期

## 3. Derivation Chains
- `Favorite.displayOrder = -favoritedAt.timestamp`（倒序）
- `Favorite.expiresAt = session.anonymous ? favoritedAt + 7d : null`

## 4. Invariants
- Article: **无不变量**（此处的 Article 是被引用方，不因本功能引入新约束）
- Favorite: `userId != null XOR sessionId != null`（要么归属用户要么归属匿名会话）
- Favorite: `expiresAt === null → user.isAuthenticated`
- AnonymousSession: `createdAt + maxLifetime >= now`（过期会话不应继续存在）

## 5. Reuse Check
| 需要 | 已有（搜索后确认） | 决策 |
|------|------------------|------|
| 会话管理 | `auth/session.*`（项目实际路径） | 扩展：加 anonymous 字段 |
| 时间 TTL | 项目里的 date util | 复用 |

## 6. Open Questions
- 登录后匿名收藏是否迁移到用户账户？
```

这个模型约 25 行，但 Spec 阶段几乎可以直接从它推出所有测试场景。
