# Step B: 识别派生关系（问三个问题）

对每个字段问：

1. **"这个值是调用方主动输入的，还是我能从别的值算出来？"**
   - 能算出来 → 派生值，不应作为独立输入
2. **"如果有两个字段，调用方只改了其中一个，会不会出现不一致？"**
   - 会 → 它们之间有派生关系，应只暴露根变量
3. **"这个字段的值范围由什么决定？"**
   - 由另一个字段决定 → 派生或约束关系

## 典型派生模式

| 类别 | 例子 |
|------|------|
| 几何派生 | `borderRadius = height / 2`, `width = height * aspectRatio` |
| 聚合派生 | `total = sum(items.price * items.quantity)` |
| 时间派生 | `expiresAt = createdAt + TTL`, `age = now - birthDate` |
| 状态派生 | `isExpired = now > expiresAt`, `canCancel = status === 'pending'` |
| 逻辑派生 | `hasDiscount = coupon !== null && coupon.valid` |

## 视觉领域派生

本质与上述相同，在 UI/布局场景中的具体化：

| 类别 | 例子 |
|------|------|
| 尺寸联动 | `padding = f(size)`, `iconSize = f(size)`, `fontSize = f(size)` |
| 响应式断点 | `columns = width >= 1200 ? 4 : width >= 768 ? 2 : 1` |
| 间距系统 | `gap = baseUnit * spacingScale`, `margin = gap * 2` |
| 布局约束 | `sidebarWidth = totalWidth - contentMinWidth`, `maxHeight = viewportHeight - headerHeight - footerHeight` |
| 可见性派生 | `showSidebar = width >= breakpoint`, `truncated = textLength > maxChars` |

视觉领域的派生关系填入建模文件的 **Derivation Chains** 章节（与其他派生并列），不需要独立章节。
