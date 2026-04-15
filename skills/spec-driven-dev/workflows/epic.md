# Epic 处理：多单元建模 + Plan 步骤

当需求为 Epic 时，进入 spec-driven-dev 的 Spec 层之前的顺序是：

1. **多单元建模** → 调用 `modeling-first`（v0.3+）"多模块需求的处理"流程，识别所有建模单元并产出 `docs/models/<scenario>/<name>.md`
2. **Plan**（基于产出的建模文件做模块拆解）→ 产出 `plan.md`

> **v3 变更（必读）**：旧版 spec-driven-dev 有"Epic 建模（产出 epic-model.md）+ 模块建模（产出 <module>/model.md）"的两层结构。v3 起建模**只有一层**——跨模块概念下沉到模块（具体归属以 `modeling-first/references/cross-module.md` 为权威）：
> - 跨模块关系 → **引用方**单元的 `Relationships` 章节（用契约线索格式：`event: ... / ref: ... / cmd: ... / snapshot: ...`），以 `Rel.*` 锚点形式存在；引用方通常是 `domain/<name>.md`，也可以是 `process/<name>.md`
> - 跨模块不变量 → **执行者**模块的 domain/process 单元，`Invariant.<Entity>.cross.<N>` 锚点
> - 跨模块共享 UI → `docs/models/components/<family>.md`
>
> Plan 直接消费这些单元的建模锚点（`Aggregate.*` / `Rel.*`），不再需要 Epic 级轮廓模型。

## Step ①：多单元建模

Plan 无法独立判断模块边界——没有建模文件就会按技术直觉切，结果通常破坏聚合边界（例如把 `Order` 和 `OrderItem` 切到两个模块）。

因此 Plan 之前必须调用 `modeling-first`（v0.3+）产出/更新所有受影响的建模单元：

- **首次建模**（项目里没有任何 `docs/models/` 下的相关文件）→ 调用 `modeling-first` 完整模式，在一次调用内：
  1. 识别单元清单（每个形如 `<scenario>/<name>`）
  2. 产出切分提议（单元清单 + 核心关注点 + 单元间依赖 + 推荐建模顺序）
  3. 按推荐顺序逐个产出 `docs/models/<scenario>/<name>.md`
- **Epic 扩展 / 二期需求**（已有部分建模单元）→ 对每个**已存在**的单元走增量建模：先读完整文件 + 漂移对齐，再追加新条目；对每个**新增**的单元走完整模式

### 产出要求（建模层）

每个 `docs/models/<scenario>/<name>.md` 必须包含（按 `modeling-first` 模板）：

- **头部字段**：Unit / Context / Source / Date
- **Aggregates 前置章节**（`domain/` 单元必填；其他 scenario 写 `Aggregate.none` + 理由）
- **6 个必填编号章节**：Entities / Relationships / Derivation Chains / Invariants / Reuse Check / Open Questions
- **可选章节**（按需）：State Machine / Process Model / Component Identification / API Surface
- **稳定锚点**：每条实体/关系/不变量/派生关系/聚合/状态机/流程/组件必须带显式 `<!-- anchor: <Namespace>.<Name> -->` 注释（命名空间按 scenario 划分的清单见 `guides/upstream-ref.md`；`modeling-first` 扩展命名空间时以其为准），供 Plan 和下游 Spec 标注 `upstream-ref`

具体方法论、模板与判定细节见 `skills/modeling-first/SKILL.md` 及 `skills/modeling-first/templates/model.md`——本 skill 不重复声明。

**建模可迭代**：Plan 或模块实现阶段若发现建模错误，回到本步骤修正后重走（见下方"迭代回流规则"）。

## Plan 的职责

Plan 回答三个问题，**仅此三个**：

1. **What** — 有哪些模块（每个模块的名称和边界）
2. **Order** — 依赖关系（哪些必须串行，哪些可以并行）
3. **Contract** — 模块间接口（上游产出什么，下游消费什么）

Plan **不回答**实现细节（协议格式、API 签名、状态机定义）——这些属于各模块的 Spec。

**Plan 的硬约束**（来自建模文件）：

- **一个聚合不得跨模块**（违反即破坏事务边界和不变量维护）——每个 `Aggregate.*` 锚点最多被一个 Plan 模块"持有"
- **模块间契约必须对应某个建模单元的 `Rel.*` 锚点**（Rel 锚点由引用方单元持有，通常在 `domain/<name>.md`，也可以在 `process/<name>.md`；不接受 `ui/` 或 `components/` 的 Rel 作为跨模块业务契约）；不得凭空新造跨模块依赖
- 若 Plan 发现某建模单元的聚合划分有问题，必须先修该单元的建模再调 Plan

## Plan 输出格式

**必须基于 `templates/plan.md` 模板**。每个模块一个条目：

```markdown
## Module: [模块名称]

- **持有聚合**：[聚合名 + `upstream-ref: <path>/domain/<name>.md#Aggregate.<Name>`；可多项；无则写"无聚合，纯派生/协调逻辑"]
  - 例：`Order Aggregate (upstream-ref: docs/models/domain/order.md#Aggregate.Order)`
- **边界**：[这个模块负责构建什么，一句话]
- **模块依赖**：[消费的上游契约，每项 `<module> 的 <契约名> (upstream-ref: <引用方 domain 或 process 单元>#Rel.<A>-<B>)`；无则写"无"]
  - 例：`user 模块的"用户匿名化事件" (upstream-ref: docs/models/domain/order.md#Rel.Order-User)`（Rel 锚点由**引用方**单元持有，通常是 domain 单元；涉及流程主导的跨模块关系可放在 process 单元）
- **产出契约**：[本模块暴露给下游的接口/能力，每项带 `upstream-ref` 指向本模块引用方单元中的 `Rel.*` 锚点]
- **复杂度**：[Trivial / Simple / Medium / Complex]
```

加上依赖关系图（文字或 ASCII 表示模块串/并行关系）。

Plan 尾部追加 Progress 节（初始状态全为 pending，流程执行中逐步更新）：

```markdown
## Progress

| 模块 | 步骤 | 状态 | 备注 |
|------|------|------|------|
| order | — | pending | |
| payment | — | pending | 依赖 order |
| notification | — | pending | 依赖 order |
```

每个模块的步骤完成后，立即更新对应行。这是新会话续接 Epic 进度的唯一依据。

**硬约束校验（Plan 生成后 fail-closed 机械校验）**：

分两层校验，任一层失败 Plan 即无效：

1. **结构约束 + 聚合落位**（由 `scripts/check-plan-structure.sh --plan <path> --upstream <list>` 强制）：
   - 每个聚合有且仅出现在一个模块的"持有聚合"字段中（禁止聚合被切散）
   - "模块依赖"和"产出契约"字段的每个 `upstream-ref` 必须指向 `Rel.*` 锚点（禁止凭空新造跨模块契约、禁止用 `Aggregate.*` / `Entity.*` 等非关系类型）
   - "持有聚合"字段的每个 `upstream-ref` 必须指向 `Aggregate.*` 锚点
   - **`--upstream` 参数是 Epic 场景的硬性要求**：必须传入本 Epic 涉及的所有 `domain/*.md`（以及包含 `Aggregate.*` 的其他单元）。脚本据此枚举所有上游 `Aggregate.*` 锚点，确保每个都被某个 Plan 模块持有（聚合未落位 → exit 5）。**省略 `--upstream` 等于跳过聚合落位校验，等于放过"聚合未落位"错误——在 Epic 场景不允许**。单模块（非 Epic）场景没有跨模块聚合归属问题，`--upstream` 可以省略
2. **锚点存在性**（由 `scripts/check-upstream-coverage.sh` 强制）：
   - 所有 `upstream-ref` 引用的锚点必须在对应建模文件（`docs/models/<scenario>/<name>.md`）中以 `<!-- anchor: ... -->` 注释形式存在
   - 多单元场景按身份分别运行（见 `guides/upstream-coverage.md` 的"Epic 多模块场景的调用方式"）

两个脚本都必须在 Plan Review 之前运行并通过——CI 与 Auto 模式的 Plan 审查步骤都将这两条作为 fail-closed 门禁。

## Plan 的完整流程

```
Epic 需求
  ↓
[多单元建模]（modeling-first"多模块需求的处理" → docs/models/<scenario>/<name>.md × N）
  ↓
[Plan 生成]（基于建模文件 → AI 生成模块拆解草稿 → 人修订）
  ↓
[机械校验]（check-plan-structure.sh + check-upstream-coverage.sh 全过）
  ↓
[Human Plan Review]（确认边界合理、依赖正确、契约完整、与建模一致）
  ↓
按依赖顺序，对每个模块：
  [增量建模（按需）]（实现中发现遗漏时，对相关建模单元增量更新；若触发聚合边界/跨模块契约变化 → 回修 Plan）
    ↓
  [Model → Spec → Review → Scenario → ... → Impl → CI]（完整步骤见 SKILL.md）
       │  DoR 消费：本模块所涉及的建模单元的全部锚点
       │  每个产出带 upstream-ref，指向建模条目的锚点

  Module A（Complex）: Spec → Review → Scenario → Review → Tests → Test Review → Red Run → Baseline → Impl → Upstream Coverage → CI
  Module B（Medium）:  Spec → Review → Scenario → Tests → Test Review → Red Run → Baseline → Impl → Upstream Coverage → CI  ← 依赖 A
  Module C（Simple）:  Spec → Scenario → Tests → Red Run → Baseline → Impl → Upstream Coverage → CI                          ← 并行于 B
```

## Plan Review 检查点

人工审查 Plan 时确认：

- ✅ **与建模文件一致**：每个聚合完整落在单个模块内（无聚合被切散）
- ✅ **契约来自建模**：模块间契约对应某个 `domain/<name>.md` 或 `process/<name>.md` 的 `Rel.*` 锚点（Rel 由引用方单元持有），无凭空新造
- ✅ 每个模块边界清晰、职责单一
- ✅ 没有模块承担了它不该承担的职责（实现细节不在 Plan 里）
- ✅ 依赖关系图完整（没有循环依赖，没有遗漏的集成点）
- ✅ 每个模块的产出契约足够明确，下游可以据此写 Spec
- ✅ 并行路径识别合理（可以并行的没有被串行化）
- ✅ 跨模块不变量（`Invariant.*.cross.*`）的执行者归属清晰（每条在唯一模块中执行）
- ✅ `scripts/check-plan-structure.sh` 和 `scripts/check-upstream-coverage.sh` 均通过

## 迭代回流规则

模块级实施（建模增量、Spec、Scenario、Test、Impl）过程中发现建模有误或聚合边界需调整时，按以下规则回流。不允许在 Spec / Scenario / Test 中"绕过"建模文件。

### 判定什么算"建模有误"

- **聚合划错**：某建模单元把应在同一聚合的实体切到两个聚合（或反之）
- **跨模块关系遗漏**：两个模块实际需要跨模块通信，但没有任何 `domain/<name>.md` 声明对应 `Rel.*` 锚点
- **跨模块不变量归属错**：`Invariant.*.cross.*` 被错误地放在非执行者模块
- **跨 scenario 冲突**：`ui/` 引入了与 `domain/` 同名但语义不同的实体（违反"Source of Truth"）

### 回流步骤

| 发现时机 | 已完成产物的处理 |
|---------|----------------|
| 模块 X 正在建模（增量）、Spec 尚未开始 | 修建模文件 → 如果 Plan 受影响（聚合归属变化、跨模块契约变化）则同步改 Plan（重走机械校验 + Plan Review）→ 模块 X 重新确认建模边界 |
| 模块 X 的 Spec / Scenario 已完成、Tests 尚未开始 | 修建模 + Plan → **失效**模块 X 的 Spec / Scenario（标记 `stale: upstream 回修`）→ 重写 Spec / Scenario（可基于旧版增量修改，但必须明确 diff） |
| 模块 X 的 Tests 已完成、Impl 未开始 | 同上 + 失效 Tests；重新建模后评估：若接口契约未变，Tests 可保留；若契约变了，Tests 失效重写 |
| 模块 X 的 Impl 已完成、其他模块也进展中 | **必须升级给用户裁决**。由用户决定：回滚 X / 向前兼容修补 / 重做建模后整体重做 |
| 已完成的上游模块 Y 被建模修改影响 | 若 Y 的持有聚合或对外契约变化 → 同样失效 Y 的 Spec 起下游产物，按同规则重做；若仅 Y 的内部细节被影响而契约稳定 → Y 只需更新相关建模单元 |

### 防循环

- 同一轮 Epic 中，建模回修 ≥ 3 次（累计所有单元）→ 暂停执行，升级给用户判断是否需要重新拆 Epic 或缩小范围
- 回修必须明确记录 `upstream-change-log.md`（存放在 `spec/` 目录，与 `plan.md` 同级）。格式：

  ```markdown
  ## 回修 #N — <ISO-timestamp>

  - **触发模块**：<发现问题的模块名>
  - **受影响单元**：<具体的 docs/models/<scenario>/<name>.md 文件清单>
  - **修改内容**：<建模文件中具体修改了什么（锚点/聚合/关系）>
  - **原因**：<为什么需要修改>
  - **影响范围**：<哪些模块的哪些产物需要失效/重做；是否触发 Plan 回修>
  ```

### 非 Epic 模式不适用

单模块需求的建模回流遵循普通 Spec 迭代规则（见 `guides/iteration-rules.md`），但仍须维护 `upstream-change-log.md` 作为审计线索。
