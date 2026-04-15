# upstream-ref 规范（唯一定义点）

> **本文件是 upstream-ref 语法、锚点命名、N/A 规则的唯一权威定义。** 所有 prompt、workflow、guide 文件引用本文件，不得各自重新定义。

## 语法

```
upstream-ref: <doc>#<anchor>[, <doc>#<anchor>]*
或
upstream-ref: N/A + <具体理由>
```

## `<doc>` 约束

建模文件的路径，必须以下述形式作结尾（最后两段路径段）：

```
<scenario>/<name>.md
```

其中：

- `<scenario>` 必须是 `modeling-first` v0.3+ 的 5 个固定 scenario 之一：`domain` / `ui` / `components` / `process` / `state-machine`
- `<name>` 是 kebab-case（小写字母+数字+连字符，首位字符必须是字母或数字）

允许写相对路径或完整路径（如 `docs/models/domain/orders.md` 与 `domain/orders.md` 都可——身份由最后两段决定）。`model.md` / `epic-model.md` 这类旧 basename 已**不再接受**：
- 用在 `--upstream` 参数上（注册 upstream 时路径不合规）→ `scripts/check-upstream-coverage.sh` 在加载阶段 `exit 1`（usage error）
- 用在产物的 `upstream-ref` 字段或矩阵行上 → 被 Check 1 以 `exit 2` 拒绝（fake upstream reference）

> `modeling-first` 的产物放置规则见 `skills/modeling-first/SKILL.md`、`skills/modeling-first/references/placement.md`——5 个 scenario 的语义及选择依据是那里的权威定义，本文件跟随其约定。

## `<anchor>` 约束

必须以 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释**形式在建模文件中显式声明。机械校验只认这种形式——heading / bold / 纯节标题**不被接受**。

### 锚点命名空间（按 scenario 划分，当前参考清单）

**机械校验规则**（`scripts/check-upstream-coverage.sh` 与 `scripts/check-plan-structure.sh` 共享）：

1. **形状**：锚点必须匹配 `^[A-Z][A-Za-z0-9]*\.[A-Za-z0-9._-]+`——即大驼峰前缀 + `.` + 名字
2. **存在性**：`<doc>#<anchor>` 引用的锚点必须在对应建模文件中以 `<!-- anchor: X -->` 注释形式真实声明（Check 1 硬卡点）
3. **路径有效性**：`<doc>` 的最后两段必须匹配 `<scenario>/<name>.md`；其他路径一律视为无效引用

脚本**不闭枚举命名空间**：`modeling-first` 新增命名空间无需同步改脚本。命名空间**合法性**（是否属于当前约定的类别、是否适配对应 scenario）由 `prompts/upstream-review.md` 的建模审查兜底——Auto 模式建模审查强制；标准模式按复杂度执行（详见 `guides/complexity.md`）。

下方清单是**当前约定**的参考（与 `modeling-first/references/anchors.md` 保持一致），供生成与审查时参考；扩展命名空间时以 `modeling-first` 为唯一真理源，本文件跟随更新即可。

**`domain/<name>.md` 可用**：

| 命名空间 | 格式 | 示例 |
|---------|------|------|
| `Aggregate` | `Aggregate.<Name>`（Aggregates 前置章节声明）| `Aggregate.Order` |
| `Entity` | `Entity.<Name>`（业务实体的唯一主权定义）| `Entity.Order` |
| `Rel` | `Rel.<A>-<B>`（持有方在前，承载跨模块契约线索）| `Rel.Order-User` |
| `Derivation` | `Derivation.<Entity>.<field>` | `Derivation.Order.total` |
| `Invariant` | `Invariant.<Entity>.<N>`（N 从 1 起）| `Invariant.Order.3` |
| `Invariant.*.cross` | `Invariant.<Entity>.cross.<N>`（跨模块不变量，本模块为执行者）| `Invariant.Order.cross.1` |
| `StateMachine` | `StateMachine.<Entity>` 或 `StateMachine.<Entity>.<Name>` | `StateMachine.Order` / `StateMachine.Order.Payment` |
| `Process` | `Process.<Name>`（独立度高建议拆到 `process/`）| `Process.Checkout` |

**`ui/<name>.md` 可用**：

| 命名空间 | 格式 | 示例 |
|---------|------|------|
| `Entity` | `Entity.<Name>`（UI 视图模型 / 展示投影，**不得与 `domain/` 同名实体重复**）| `Entity.OrderSummary` |
| `Rel` | `Rel.<A>-<B>`（视图间或视图与页面的关系）| `Rel.OrderList-OrderDetail` |
| `Derivation` | `Derivation.<Entity>.<field>`（视觉领域派生）| `Derivation.OrderCard.badgeColor` |
| `Invariant` | `Invariant.<Entity>.<N>`（UI 约束）| `Invariant.OrderList.1` |
| `StateMachine` | `StateMachine.<Entity>[.<Name>]`（拖拽、模态框、多步表单等 UI 状态机）| `StateMachine.OrderDialog` |
| `Component` | `Component.<Name>`（本单元内部共享的 UI 组件；跨模块共享的升级到 `components/`）| `Component.OrderCard` |

**`components/<family>.md` 可用**：

| 命名空间 | 格式 | 示例 |
|---------|------|------|
| `Component` | `Component.<Name>`（组件定义的唯一主权定义，通用组件或业务共用组件）| `Component.Modal` |
| `Derivation` | `Derivation.<Component>.<field>` | `Derivation.Modal.zIndex` |
| `StateMachine` | `StateMachine.<Component>[.<Name>]` | `StateMachine.Modal` |
| `Invariant` | `Invariant.<Component>.<N>` | `Invariant.Modal.1` |
| `Rel` | `Rel.<A>-<B>`（组件间关系，如 Modal 嵌套 Form）| `Rel.Modal-Form` |

**`process/<name>.md` 可用**：

| 命名空间 | 格式 | 示例 |
|---------|------|------|
| `Process` | `Process.<Name>`（流程主体，核心产出）| `Process.Refund` |
| `Rel` | `Rel.<A>-<B>`（流程与其他单元之间的关系，承载契约线索）| `Rel.Refund-Order` |
| `StateMachine` | `StateMachine.<Entity>[.<Name>]`（仅当状态机是流程私有的）| `StateMachine.RefundStep` |
| `Invariant` | `Invariant.<Subject>.<N>`（流程内部约束，如并发/幂等/超时；`<Subject>` 可以是 `Process` 或被引用的实体名）| `Invariant.Process.1` |
| `Invariant.*.cross` | `Invariant.<Subject>.cross.<N>`（跨模块约束，本单元为执行者）| `Invariant.Process.cross.1` |

> 业务实体（含聚合内部实体，如 `ApprovalStep`、`OrderItem`）归属于对应的 `domain/<name>.md`，**不在 `process/` 定义**。`process` 单元通过 `upstream-ref` 引用业务实体。

**`state-machine/<name>.md` 可用**：

| 命名空间 | 格式 | 示例 |
|---------|------|------|
| `StateMachine` | `StateMachine.<Entity>[.<Name>]`（状态机主体）| `StateMachine.Upload` |
| `Invariant` | `Invariant.<Entity>.<N>`（状态机约束）| `Invariant.Upload.1` |

### 例外写法（显式标记无内容，不视为违反命名空间规则）

- `Invariant.<Subject>.none` — 该主体显式无不变量（需给出理由）。`<Subject>` 范围与上方各 scenario 段的 `Invariant.<...>` 主体一致
- `Aggregate.none` — 本单元不持有聚合（适用于非 `domain/` 的单元）

锚点形状正则（脚本只校验到这一层）：`[A-Z][A-Za-z0-9]*\.[A-Za-z0-9._-]+`

> 上述清单是**当前约定**，与 `modeling-first/references/anchors.md` 保持一致。`modeling-first` 如扩展新命名空间，本表同步更新即可——`check-upstream-coverage.sh` / `check-plan-structure.sh` 不需要改动（它们只做形状校验 + 存在性校验 + 路径 scenario 校验）。命名空间的**合法性**语义由 `prompts/upstream-review.md` 的建模审查兜底。

## 多条引用

一个产出可对应多条锚点，用逗号分隔：

```
upstream-ref: domain/order.md#Invariant.Order.3, domain/order.md#Derivation.Order.total
```

## N/A 规则

仅当确实不对应任何建模条目时可标 `N/A`（如纯基础设施测试、兼容性回归测试），**必须附具体理由**。审查时会质问理由合理性。

不接受的理由：
- "这个场景太基础了"
- "这条不变量太难测"
- "这个派生关系很显然"

## 各阶段的落位方式

| 阶段 | upstream-ref 位置 |
|------|-----------------|
| Plan | `持有聚合` 指向 `domain/<name>.md#Aggregate.<Name>`；`模块依赖` / `产出契约` 指向**引用方单元**的 `Rel.<A>-<B>` 锚点（通常是 `domain/<name>.md`，也可以是 `process/<name>.md`——以 `modeling-first/references/cross-module.md` 权威规则为准） |
| Spec | 每条 Rule / State / State Transition 末尾行内标注 `（upstream-ref: <doc>#<anchor>）` |
| Scenario | 每个场景末尾 `↑ upstream-ref: ...`（格式见 `guides/scenario-format.md`）|
| Test | 顶部注释 `@upstream ...` 或测试名前缀（格式见 `prompts/test-implementation.md`）|
| Impl | 关键位置注释 `// covers <upstream-ref>`；详细追溯由 Upstream Coverage Matrix 承载 |
| Coverage Matrix | 每条 upstream 条目占一行（格式见 `guides/upstream-coverage.md`）|

## 越界禁令

场景/Spec/Test 不允许引入建模文件中未声明的行为。若发现需要新的业务规则 → 先回修建模，再写下游产物。
