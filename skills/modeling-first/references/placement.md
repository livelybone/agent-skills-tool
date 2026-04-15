# 产物放置规则

## 建模单元的定义

**"建模单元" = scenario × 业务模块**（与 SKILL.md 主文档术语一致）。同一业务（如"订单"）在不同 scenario 下是不同的建模单元：

- `docs/models/domain/orders.md` — 订单的领域建模（实体、聚合、业务不变量）
- `docs/models/ui/orders.md` — 订单相关的 UI 建模（列表页、详情页、交互）

两者是独立的 model 文件，通过 `upstream-ref` 互相引用，不允许重复定义同名实体。

## Scenario 清单（固定 5 个，不允许扩展）

| Scenario | 主要关注点 | 典型章节 |
|---------|----------|---------|
| `domain/` | 业务领域：实体、聚合、业务不变量、业务派生 | Aggregates、Entities、Relationships、Derivation、Invariants |
| `ui/` | 前端应用：页面、视图、交互、UI 状态 | Entities（视图模型）、Component Identification、视觉派生、State Machine（UI 状态机） |
| `components/` | UI 组件建模 | 视觉派生、State Machine（组件状态）、API Surface |
| `process/` | 独立业务流程（不依附于某个领域实体） | Process Model、State Machine |
| `state-machine/` | 独立状态机（罕见，通常附在 domain/ui 里） | State Machine（主体内容） |

> **选择口诀**：主要建模对象是"业务对象（订单/支付）" → `domain/`；是"页面/视图/布局/组件协作" → `ui/`；是"可复用的 UI 单元本身" → `components/`；是"独立流程/状态机"→ `process/` 或 `state-machine/`

## 目录结构

```
docs/models/
├── domain/
│   ├── orders.md
│   ├── payments.md
│   └── refunds.md
├── ui/
│   ├── orders.md             ← 订单相关 UI
│   ├── membership-center.md
│   └── checkout.md
├── components/
│   ├── form.md               ← 通用组件按 family 分
│   ├── overlay.md
│   ├── feedback.md
│   ├── layout.md
│   ├── primitive.md
│   └── business-shared.md    ← 业务共用组件（提升后）
├── process/
│   └── expense-reimbursement.md
└── state-machine/
    └── onboarding-flow.md
```

## 命名与路径规则

- **文件名 = 建模单元名** `<name>.md`（如 `orders.md`、`membership-center.md`）。名称用 kebab-case，小写
- **路径**：`docs/models/<scenario>/<name>.md`，以 repo 根为基准
- **`upstream-ref` 完整路径**：`docs/models/domain/orders.md#Entity.Order`
- 同名可跨 scenario 复用（`domain/orders.md` 和 `ui/orders.md` 合法）
- `{scenario}` 必须来自上面固定的 5 个

## Source of Truth 跨 scenario 规则

同一概念只能在一个 scenario 定义，其他引用：

表中路径全部为 repo 根下的完整路径形式（`docs/models/<scenario>/<name>.md#<Anchor>`）。

| 概念 | 主权所在 | 其他如何引用 |
|-----|---------|-------------|
| 业务实体（Order、Payment、User） | `docs/models/domain/<name>.md#Entity.<Name>` | `ui/`、`process/`、`components/` 通过 `upstream-ref` 引用 |
| UI 视图模型（OrderSummary、FavoriteItem 等展示投影） | `docs/models/ui/<name>.md#Entity.<Name>` | 需要时通过 `upstream-ref` 引用 |
| 通用组件（Button、Modal 等） | `docs/models/components/<family>.md#Component.<Name>` | `ui/`、`domain/` 通过 `upstream-ref` 引用 |
| 业务共用组件（StatusCard 等） | `docs/models/components/business-shared.md#Component.<Name>` | `ui/`、`domain/` 通过 `upstream-ref` 引用 |
| 业务不变量（跨模块） | 执行者模块（通常在 `docs/models/domain/<name>.md` 下） | 其他 `domain/`、`ui/` 模块引用 |

**重要约束**：`ui/` 不得重新定义 `domain/` 已有的同名实体。要么 `upstream-ref` 引用，要么定义一个不同名的视图模型（如 `OrderSummary` 而非 `Order`）。

## 通用组件 vs 业务共用组件

| | 通用组件 | 业务共用组件 |
|---|---------|-------------|
| 例子 | Button, Input, Modal, Dropdown | StatusCard（orders+refunds 都用）、MembershipTier |
| 业务语义 | 无 | 有 |
| 放置 | `docs/models/components/<family>.md`（按 family 分组） | **首次使用时就近放在引入模块；第二次被使用时提升至 `docs/models/components/business-shared.md`** |

**业务共用组件的提升规则**：

1. 第一次引入时 → 放在引入该组件的业务模块的 Component Identification 章节（如 `ui/orders.md`）
2. 当第二个模块要用它时 → 提升到 `docs/models/components/business-shared.md`
3. 提升 = **路径变更**，是"锚点不得删除/重命名"约束的**显式例外**。提升步骤必须严格按以下顺序执行，并视为需升级给用户的变更（因为它会破坏下游 `upstream-ref`）：
   1. 在 `docs/models/components/business-shared.md` 新增 `<!-- anchor: Component.<Name> -->` 主权定义（含输入、职责、状态机等完整内容）
   2. 全仓搜索原路径 `<原文件>#Component.<Name>` 的**所有引用**（包括 `upstream-ref`、普通 markdown 链接 `[..](<path>#Component.<Name>)`、其他 hash 形式引用），全部改为指向新路径 `docs/models/components/business-shared.md#Component.<Name>`
   3. 在原引入模块（如 `docs/models/ui/orders.md`）的 Component Identification 章节中：
      - **删除**原 `<!-- anchor: Component.<Name> -->` 锚点和该组件的完整定义
      - 在"跨单元共享（引用形式）"子节用 `upstream-ref: docs/models/components/business-shared.md#Component.<Name>` 引用
   4. 第二个使用方模块（新引入方）也用同样的 `upstream-ref` 形式引用，不复制定义
   5. 在两个使用方模块的 Open Questions 中显式记录"组件 X 已提升至 docs/models/components/business-shared.md，原锚点已迁移"，供用户复核
4. 若下游有 `upstream-ref` 无法同步更新（如跨仓引用），暂停升级给用户裁决，不得擅自提升

## 多模块需求的建模顺序

需求涉及多个 `scenario × 业务模块` 组合时（如引入退款触及 `domain/orders` + `domain/refunds` + `ui/orders`）：

1. 列出所有受影响的 `<scenario>/<name>.md` 清单
2. 按依赖顺序建模：通常 `domain/` → `ui/` → `components/`
3. 已存在的走增量建模，新的走全量建模
4. 流程细节见 `SKILL.md` "多模块需求的处理"章节

## 漂移对齐规则

增量建模时必须先检查 md 与代码的对齐情况。若发现漂移（代码已变但 md 未更新）：

1. **先对齐**：把 md 拉回当前代码的真实状态（修正过时的实体字段、已删除的派生、已改变的状态机转换等）
2. **标注修正**：在 Open Questions 中记录此次对齐修正的范围
3. **再做增量**：在对齐后的 md 上追加本次增量改动

这让每次增量建模成为漂移的自然校正时机，不积累成负债。
