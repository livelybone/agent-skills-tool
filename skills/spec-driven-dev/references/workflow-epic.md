# Epic 处理：Epic 建模 + Plan 步骤

当需求为 Epic 时，进入 spec-driven-dev 流程之前的顺序是：

1. **Epic 建模** → 调用 `modeling-first` 轮廓模式，产出 `epic-model.md`
2. **Plan**（基于 `epic-model.md` 切分模块）→ 产出 `plan.md`

## Step ①：Epic 建模

Plan 无法独立判断模块边界——没有建模文件就会按技术直觉切，结果通常破坏聚合边界（例如把 `Order` 和 `OrderItem` 切到两个模块）。

因此 Plan 之前必须调用 `modeling-first` 产出/更新 `epic-model.md`：

- **无 `epic-model.md`** → 全量建模（轮廓模式）
- **已有 `epic-model.md`**（如 Epic 扩展、二期需求）→ 增量建模：在现有文件上追加新聚合/关系/共享不变量/锚点，经审查后继续 Plan

### 产物要求（Epic 级）

`epic-model.md` 必须包含：

- **聚合清单**：每个聚合的根实体和内部实体
- **跨聚合关系**：哪些聚合间有引用或事件依赖（这些是 Plan 中契约的来源）
- **跨模块共享不变量**
- **稳定锚点**：每条实体/关系/不变量/聚合必须带 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释形式的显式锚点**（命名空间：`Entity` / `Rel` / `Invariant` / `Aggregate` / `SharedInvariant`；机械校验只认这种形式），供下游标注 `upstream-ref`

具体方法论、模板与判定细节见 `skills/modeling-first/SKILL.md` 及 `skills/modeling-first/templates/epic-model.md`——本 skill 不重复声明。

`epic-model.md` 可迭代：模块建模阶段若发现错误，回到本步骤修正后重走 Plan。

## Plan 的职责

Plan 回答三个问题，**仅此三个**：

1. **What** — 有哪些模块（每个模块的名称和边界）
2. **Order** — 依赖关系（哪些必须串行，哪些可以并行）
3. **Contract** — 模块间接口（上游产出什么，下游消费什么）

Plan **不回答**实现细节（协议格式、API 签名、状态机定义）——这些属于各模块的 Spec。

**Plan 的硬约束**（来自 `epic-model.md`）：

- 一个聚合不得跨模块（违反即破坏事务边界和不变量维护）
- 模块间契约必须对应 `epic-model.md` 的跨聚合关系；不得凭空新造跨模块依赖
- 若 Plan 发现 `epic-model.md` 的聚合划分有问题，必须先修 `epic-model.md` 再调 Plan

## Plan 输出格式

每个模块一个条目：

```markdown
## Module: [模块名称]

- **持有聚合**：[聚合名 + `upstream-ref: epic-model.md#Aggregate.<Name>`；可多项；无则写"无聚合，纯派生/协调逻辑"]
  - 例：`Order Aggregate (upstream-ref: epic-model.md#Aggregate.Order)`
- **边界**：[这个模块负责构建什么，一句话]
- **模块依赖**：[消费的上游契约，每项 `<module> 的 <契约名> (upstream-ref: epic-model.md#Rel.<A>-<B>)`；无则写"无"]
  - 例：`user 模块的"用户匿名化事件" (upstream-ref: epic-model.md#Rel.Order-User)`
- **产出契约**：[本模块暴露给下游的接口/能力，每项带 `upstream-ref` 指向对应跨聚合关系]
- **复杂度**：[Trivial / Simple / Medium / Complex]
```

加上依赖关系图（文字或 ASCII 表示模块串/并行关系）。

**硬约束校验（Plan 生成时自动检查）**：

- 每个聚合有且仅出现在一个模块的"持有聚合"字段中
- 所有"模块依赖"和"产出契约"项必须能在 `epic-model.md` 的"跨聚合关系"中找到对应关系；不得凭空新造
- 每个模块的"持有聚合"必须指向 `epic-model.md` 中存在的聚合锚点（`upstream-ref` 形式），否则 Plan 无效

## Plan 的完整流程

```
Epic 需求
  ↓
[Epic 建模]（modeling-first 轮廓模式 → epic-model.md）
  ↓
[Plan 生成]（基于 epic-model.md → AI 生成模块拆解草稿 → 人修订）
  ↓
[Human Plan Review]（确认边界合理、依赖正确、契约完整、与 epic-model 一致）
  ↓
按依赖顺序，对每个模块：
  [模块建模]（调用 modeling-first → <module>/model.md；无则全量，有则增量）
       │  约束：引用 epic-model.md 的共享实体，不重定义
       │  若发现 epic-model.md 有误 → 回到 Epic 层修正 → 重走 Plan
    ↓
  [Model → Spec → Review → Scenario → ... → Impl → CI]（完整步骤见 SKILL.md）
       │  DoR 消费：本模块 <module>/model.md
       │  每个产出带 upstream-ref，指向建模条目的锚点

  Module A（Complex）: model → Spec → Review → Scenario → Review → Tests → Test Review → Red Run → Baseline → Impl → Upstream Coverage → CI
  Module B（Medium）:  model → Spec → Review → Scenario → Tests → Test Review → Red Run → Baseline → Impl → Upstream Coverage → CI  ← 依赖 A
  Module C（Simple）:  model → Spec → Scenario → Tests → Red Run → Baseline → Impl → Upstream Coverage → CI                          ← 并行于 B
```

## Plan Review 检查点

人工审查 Plan 时确认：

- ✅ **与 epic-model.md 一致**：每个聚合完整落在单个模块内（无聚合被切散）
- ✅ **契约来自 epic-model**：模块间契约对应 `epic-model.md` 的跨聚合关系，无凭空新造
- ✅ 每个模块边界清晰、职责单一
- ✅ 没有模块承担了它不该承担的职责（实现细节不在 Plan 里）
- ✅ 依赖关系图完整（没有循环依赖，没有遗漏的集成点）
- ✅ 每个模块的产出契约足够明确，下游可以据此写 Spec
- ✅ 并行路径识别合理（可以并行的没有被串行化）

## 迭代回流规则

模块级完整建模时发现 `epic-model.md` 有误（聚合边界错、关系遗漏、共享不变量冲突），必须按以下规则回流。不允许在 `<module>/model.md` 里"绕过"已声明的 `epic-model.md`。

### 判定什么算"epic-model 有误"

- **聚合划错**：`epic-model.md` 把应在同一聚合的实体切到两个聚合（或反之）
- **关系遗漏**：两个模块实际需要跨模块通信，但 `epic-model.md` 没声明对应关系
- **共享不变量冲突**：多个模块对同一跨聚合约束理解不一致

### 回流步骤

| 发现时机 | 已完成产物的处理 |
|---------|----------------|
| 模块 X 正在建模、Spec 尚未开始 | 修 `epic-model.md` → 如果 Plan 受影响则同步改 Plan（重走 Plan Review）→ 模块 X 重新建模 |
| 模块 X 的 Spec / Scenario 已完成、Tests 尚未开始 | 修 `epic-model.md` + Plan → **失效**模块 X 的 Spec / Scenario（标记 `stale: upstream 回修`）→ 模块 X 重新建模 → 重写 Spec / Scenario（可基于旧版增量修改，但必须明确 diff） |
| 模块 X 的 Tests 已完成、Impl 未开始 | 同上 + 失效 Tests；重新建模后评估：若接口契约未变，Tests 可保留；若契约变了，Tests 失效重写 |
| 模块 X 的 Impl 已完成、其他模块也进展中 | **必须升级给用户裁决**。由用户决定：回滚 X / 向前兼容修补 / 重做 `epic-model.md` 后整体重做 |
| 已完成的上游模块 Y 被 `epic-model.md` 修改影响 | 若 Y 的持有聚合或对外契约变化 → 同样失效 Y 的 Spec 起下游产物，按同规则重做；若仅 Y 的内部细节被影响而契约稳定 → Y 只需更新本模块 `model.md` |

### 防循环

- 同一轮 Epic 中，`epic-model.md` 回修 ≥ 3 次 → 暂停执行，升级给用户判断是否需要重新拆 Epic 或缩小范围
- 回修必须明确记录 `upstream-change-log.md`：每次改动的原因、触发模块、影响范围

### 非 Epic 模式不适用

单模块需求不涉及 `epic-model.md`，本规则不适用；模块内部的建模迭代遵循普通 Spec 迭代规则（见 `iteration-rules.md`）。
