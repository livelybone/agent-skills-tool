---
name: modeling-first
description: "**MANDATORY prerequisite** — you MUST invoke this skill BEFORE starting any task that introduces new entities, state machines, multi-page UI components, multi-step processes, or complex business logic. Skipping it causes pattern-matching implementations (duplicate logic, parallel components, derived values exposed as inputs). 执行任务前先以 `scenario × 业务模块` 为单位建模理解（小任务用内联、文件级产出 `docs/models/<scenario>/<name>.md`，scenario 固定 domain/ui/components/process/state-machine 五选一），覆盖领域实体、状态机、业务流程、UI 组件识别等维度，适用于后端逻辑、前端视觉与交互、复杂业务拆解等所有场景。触发词：建模, modeling, 领域模型, 状态机, 拆解需求, 前端建模, 组件识别, 流程建模, 理解任务, 看板, 审批流, 列表页, 跨页面, understand task"
metadata:
  version: 0.3.0
  tags: [modeling, design, architecture, pre-implementation]
---

# Modeling First

> ⚠️ **MANDATORY prerequisite** — coding agent 在启动任何涉及新实体 / 状态机 / 多页面 UI 组件 / 多步流程 / 复杂业务逻辑的任务之前**必须**先调用本 skill。跳过本 skill 是 LLM 落入模式匹配实现（重复逻辑、平行组件、派生值误暴露）的主要原因。判断任务是否触发本 skill 的信号见下方"适用场景"。对于明确跳过条件（纯视觉调整、文案、依赖升级等），可直接进入实现，无需调用本 skill。

> **背景**：LLM 默认用模式匹配方式实现需求（见到"列表页" → 套"表格+分页+筛选"模板；见到"多状态按钮" → 直接写 5 个独立 props；见到"多页面" → 逐页复制实现），而非建模方式。结果是同一概念多处重复实现、应派生的值被当独立输入、与现有抽象平行新建相似概念、跨页面共享单元被重复实现。本 skill 强制在写代码前产出**最小结构化模型**（可以是独立文件或上下文内联），覆盖领域实体、状态机、业务流程、UI 组件识别等维度，把 LLM 从模式匹配切到建模模式。

## 领域建模的组织原则

本 skill 的建模产出组织方式：

- **以建模单元为粒度**：每个"建模单元"（scenario × 业务模块，详见"产物放置规则"）在项目中有且仅有一份 `docs/models/<scenario>/<name>.md`
- **一次调用可产出多个文件**：需求若跨多个单元，本 skill 在同一次调用内依次产出所有受影响单元的建模文件；编排调用方（如 `spec-driven-dev` 的 Plan 阶段）也可自行决定切分后，把单元范围作为输入传给本 skill
- **跨模块概念下沉到模块**：
  - 跨模块关系 → 引用方模块的 Relationships 章节（用契约线索格式：`event: ... / ref: ... / cmd: ... / snapshot: ...`）
  - 跨模块不变量 → 执行者模块的 Invariants 章节（显式标注 `[跨模块]` + 用 `upstream-ref` 引用对方模块的实体锚点）
  - 跨模块共享 UI 组件 → `docs/models/components/<family>.md`（通用组件）或 `docs/models/components/business-shared.md`（业务共用组件，详见"产物放置规则"）
  - 关键并发/金额/审计等关注点 → 执行者模块的专属章节（State Machine / Process Model / Invariants）

**项目全局视图**通过"扫描 `docs/models/` 目录下所有建模文件"聚合得到，而不是靠单一索引文件维护。

## 适用场景

判断标准是**需求是否引入新的领域信息**，不是改动范围大小。判断结果是**三级深度选择**：

### 文件级建模（满足任一即触发）

**后端/领域信号**：
- 引入**新实体**（新领域概念、新生命周期对象）
- 引入**新关系**（新的实体间关联、新的基数/所有权约定）
- 引入**新不变量**（新的状态机约束、新的合法性规则）
- 引入**新派生关系**（新的计算规则、新的根变量）
- 对现有实体引入**状态变化逻辑**（原本静态，现在有生命周期）

**前端/交互信号**：
- 需求涉及**多个页面/视图**且存在视觉重复（需要组件识别）
- 组件有**复杂状态机**（≥ 4 个状态 + 多个带条件的转换）
- 布局属性间存在**多层联动**（≥ 3 个属性互相派生）

**流程信号**：
- **多步操作**且步骤间有条件分支
- 涉及**并发/竞态**
- 涉及**回滚/补偿**逻辑

### 内联建模

任务触发了建模信号，但规模较小：涉及**单个组件/实体**、**≤ 2 个关系**、**无跨模块关注点**。典型场景：

- 单个组件有多状态（如按钮的 idle/hover/active/disabled/loading）
- 单页面的布局属性间有联动（如响应式断点决定列数）
- 单个交互有步骤序列（如拖拽排序的 idle → dragging → dropped）

> **溢出规则**：内联建模产出超过 30 行 → 升级到文件级。

### 跳过（直接进入实现）

- 单函数 bug fix（不改变领域结构）
- **纯视觉调整**（颜色、字号、圆角等不涉及状态变化或属性联动的改动）
- 文案修改、国际化
- 纯技术重构（重命名、格式化、类型收窄，不改变实体/关系/不变量）
- 对已有实体做**机械性**字段增删（新字段是独立值，不引入派生或不变量）
- 升级依赖、配置变更

**边界情况**：改动范围大但不涉及以上任一"新"的信号 → **跳过**；改动范围小但引入新的派生关系 → **至少内联**。看**领域信息增量**，不看**代码行数**。

## 两种建模模式

| 维度 | 内联模式（Inline） | 完整模式（Full） |
|------|-------------------|----------------|
| 触发场景 | 单组件/实体、≤ 2 关系、无跨模块 | 其他所有文件级触发场景 |
| 产出 | 当前上下文中的 `## Inline Model` 文本块，**不产出独立文件** | `docs/models/<scenario>/<name>.md` 文件 |
| 包含内容 | 最小结构："识别了什么" + "约束是什么" | 头部字段 + Aggregates 前置章节 + 6 个必填编号章节 + 可选章节（State Machine / Process Model / Component Identification / API Surface） |
| 规模 | 10-30 行 | 必填章节 < 150 行，每个可选章节 ≤ 30 行 |
| 锚点 | 免除 | 必须 |
| 迭代性 | 产出融入实现，不回流 | 模块内部迭代；新 Epic 触及本模块时走**增量建模** |

### 多模块需求的处理

需求跨多个建模单元时（scenario × 业务模块组合，例如同时引入 `domain/orders` + `domain/payments` + `domain/refunds` + `ui/refunds`），本 skill 在一次调用内依次处理每个受影响单元，产出对应的建模文件。

**标准流程**：

1. **识别单元清单**：列出受影响的建模单元（每个形如 `<scenario>/<name>`），标注新建 / 已有
2. **产出切分提议**（在当前对话上下文中输出 15-30 行的草案）：
   - 单元清单
   - 每个单元的核心关注点（概念层面）
   - 单元间依赖关系（粗粒度）
   - 推荐的建模顺序（被依赖的先建，通常 `domain/` → `ui/` → `components/`）
3. **coding-agent 直接按提议推进**；仅当存在无法裁决的歧义（如：某实体在两个单元间归属不明、现有 model.md 与新需求存在无法通过增量建模消化的冲突、聚合边界有多种合理划法）时才暂停请用户裁决
4. **按推荐顺序逐个产出建模文件**：对每个单元走完整模式（新单元）或增量建模（已有单元）。本 skill 在同一次调用内可产出多个文件

**coding-agent 裁决原则**：

- 保守优先：有歧义时选更安全、更受限的解释
- 一致性优先：裁决必须与已有锚点和单元边界一致，不引入矛盾
- 可追溯：每次 coding-agent 裁决都在切分提议或 Open Questions 中注明理由
- 升级边界：涉及聚合边界重大调整、业务语义解释、安全/权限敏感点时暂停给用户

**与编排调用方的协作**：

编排 skill（如 `spec-driven-dev` 的 Plan 阶段）可以自行决定模块切分，把单元清单作为输入传给本 skill；本 skill 按清单顺序逐个产出。跨单元规划（依赖图、切分草案）若需持久化，由调用方落地（如 Plan 文件或 `.plan-staging/`）；本 skill 的切分提议是对话产出，用于决策沟通。

### 增量建模

当新需求触及**已有建模文件**（`docs/models/<scenario>/<name>.md`）的建模单元时，走增量建模：

1. **先读完整**现有建模文件，理解已有的实体/关系/不变量/派生/锚点
2. **检查漂移**：对照当前代码，确认 md 反映的是真实状态；若有漂移先做对齐修正（详见"产物放置规则 → 漂移对齐规则"）
3. 评估本次变更引入的领域信息增量
4. **追加**新条目或**修改**已有条目；**已有锚点不得删除或重命名**（除非下游所有 `upstream-ref` 同步更新，这需升级给用户）
5. 增量更新后整体建模文件仍须满足质量门槛（不只是新增部分）

## 必须材料

- 需求描述（来自用户原话、brainstorming 产出、issue 链接之一）
- 目标建模单元：单个或多个 `scenario × 业务模块` 组合（见"产物放置规则"）
- 能访问项目源代码（用于 Reuse Check，内联模式可跳过）
- 产出目标路径（文件级模式）：`docs/models/<scenario>/<name>.md`，多单元需求产出多个文件（详见"产物放置规则"）

## 产物放置规则

**建模单元 = scenario × 业务模块**，路径 `docs/models/<scenario>/<name>.md`。同一业务可在多个 scenario 下存在（如 `domain/orders.md` 和 `ui/orders.md`）。

**Scenario 固定 5 个**（不允许扩展）：

| Scenario | 用于 | 选择依据 |
|---------|------|---------|
| `domain/` | 业务实体、聚合、业务不变量 | 主要建模对象是"业务对象" |
| `ui/` | 页面、视图、交互、UI 状态 | 主要是"页面/视图/组件协作" |
| `components/` | 通用组件或业务共用组件 | 主要是"可复用的 UI 单元本身" |
| `process/` | 独立业务流程 | 独立流程、不依附单一领域实体 |
| `state-machine/` | 独立状态机 | 状态机本身是主体（罕见） |

**关键约束**：

- Source of Truth：业务实体由 `domain/` 独占；`ui/` 不得重定义同名实体（引用或改名为视图模型如 `OrderSummary`）
- 业务共用组件遵循"第二次使用时提升"规则（首次就近放在使用方，第二次抽到 `docs/models/components/business-shared.md`）
- 增量建模前必须先做漂移对齐（代码已变但 md 未更新时，先修 md 再加增量）
- 文件名用 kebab-case，路径以 repo 根为基准

> 📖 **详细规则见** `references/placement.md`：目录结构全貌、Source of Truth 完整表、通用 vs 业务共用组件、提升规则细节、漂移对齐步骤、多模块建模顺序

## 执行步骤

每一步"应该做什么"在本节，"怎么做"见对应的 `references/steps/` 文件（按需读取）。

### Step 0: 判断模式与单元清单

- 文件级信号 → **完整模式**，按"产物放置规则"选 scenario，产出 `docs/models/<scenario>/<name>.md`
- 小规模信号（单组件/实体、≤ 2 关系、无跨模块） → **内联模式**，不产出独立文件
- 跨多个建模单元 → 按"多模块需求的处理"产出切分提议 → coding-agent 直接按提议推进（仅在有无法裁决的歧义时暂停请用户裁决）→ 按清单顺序逐个单元走 Step 1-8

### Step 1: 判断建模深度

用"适用场景"清单确定走**文件级 / 内联 / 跳过**。跳过 → 直接告知用户跳过本 skill 进入实现。

### Step 2: 识别实体

从需求中提取领域名词（去掉技术词"接口/页面/组件"），标注来源。

> 📖 `references/steps/step-a.md` — 名词分类、隐含名词、实体识别信号

### Step 3: 识别关系

对每对相关实体明确基数、所有权、聚合边界。跨模块关系用 `upstream-ref` 引用对方实体锚点，不在本文件重定义。漏掉关系 = 名词清单而非模型。

> 📖 `references/steps/step-a5.md` — 基数/所有权/聚合边界的 3 个判定问题
> 📖 `references/cross-module.md` — 跨模块契约线索格式（event / ref / cmd / snapshot）

### Step 4: 识别派生关系

对所有数值/时间/状态字段问"这个值能不能从其他值算出来"。能算 → 写成等式 `派生值 = f(根变量)`。不接受"与 X 有关"这种模糊描述。

> 📖 `references/steps/step-b.md` — 派生三问、典型派生模式、视觉领域派生
> 📖 `references/anti-patterns.md` — 反模式 1（派生值被当独立输入）自查

### Step 4.5: 识别状态机/流程（可选）

实体有多状态生命周期或需求涉及多步/分支/回滚时，在可选章节结构化输出。

> 📖 `references/steps/step-d.md` — 状态机四要素（states/transitions/guards/actions）
> 📖 `references/steps/step-e.md` — 流程建模（steps/conditions/rollback/concurrency）

### Step 4.6: 识别共享组件（可选，涉及多页面时）

本模块涉及多页面/视图时先横向扫描识别共享视觉单元。放置原则见"产物放置规则"（模块内 vs 跨模块 vs 提升规则）。

> 📖 `references/steps/step-f.md` — 横向扫描方法、识别标准、产出格式

### Step 5: 识别不变量

对每个实体问"什么状态非法、转换有什么约束"。用可验证形式（`total >= 0` / `status in [...]`）。每实体至少一条，真没有要显式标注"无不变量 + 理由"。

跨模块不变量（需读多个单元数据才能校验）放在**执行者模块**，标注 `[跨模块]` + `upstream-ref` 引用。

> 📖 `references/steps/step-c.md` — 不变量两问 + 价值
> 📖 `references/cross-module.md` — 跨模块不变量的执行者判定与书写格式

### Step 6: Reuse Check

实际搜索代码，每个实体/派生/工具给出具体路径和符号名。不接受"可能有"、"应该有类似的"。增量建模时先检查其他建模单元是否已定义所需实体。

> 📖 `references/anti-patterns.md` — 反模式 4（平行新建）自查

### Step 7: 产出

- **完整模式**：按 `templates/model.md` 输出 `docs/models/<scenario>/<name>.md`。多单元需求在同一次调用内按顺序产出所有受影响单元的文件
- **内联模式**：输出 `## Inline Model` 文本块（识别 + 约束 + 指导实现）

默认直接推进；仅当有无法裁决的歧义或关键 Open Questions 时才暂停请用户确认。

### Step 8: 交付产物

- 告知产出文件的完整清单或内联文本块
- 汇总每个文件的 Open Questions（需用户判断的点）
- 增量建模时，列出受影响的已有锚点（新增 / 修改）；删除属于例外路径，须先升级用户裁决再执行（同时记录理由）
- 汇总本次调用中 coding-agent 裁决过的歧义，供用户按需复核

## 产物与格式

### 内联模式

不产出独立文件。在当前上下文中输出以下结构的文本块：

```markdown
## Inline Model

**识别**：<实体/状态/组件列表>
**约束**：<不变量/转换规则/派生关系>
**指导实现**：<建模结论如何影响实现决策>
```

内联模式免除锚点要求。10-30 行，超过 30 行应升级到文件级。

> **内联模式与下游消费**：内联模式仅服务于"由当前 coding-agent 一次性消化"的小任务，不形成可机械引用的契约。**若任务后续会进入 `spec-driven-dev` 等需要 `upstream-ref` 消费建模产物的下游流程，应直接使用文件级模式**，不可用内联代替。

### 完整模式

见 `templates/model.md`。产出路径：`docs/models/<scenario>/<name>.md`（具体规则见"产物放置规则"）。结构：头部字段 + 1 个前置章节（Aggregates）+ 6 个必填编号章节 + 可选章节。

头部字段（模板顶部的元数据块，不编号，不计入"章节行数"统计）：
- **Unit** — 建模单元标识（`<scenario>/<name>`）
- **Context** — 一句话说明本单元做什么 + 需求来源
- **Source** — 需求来源
- **Date** — 建模日期

前置章节（不编号，但计入章节行数）：
- **Aggregates** — 本单元持有的聚合清单（带锚点）。`domain/` 单元必填；其他 scenario 写 `Aggregate.none` + 理由

必填编号章节（§1-§6）：
1. **Entities** — 实体清单（带需求依据，跨模块引用的实体用 `upstream-ref` 而非重定义）
2. **Relationships** — 基数、所有权、聚合边界、跨模块关系
3. **Derivation Chains** — 派生关系（等式，含视觉领域派生）
4. **Invariants** — 不变量（每个实体至少一条；跨模块不变量显式标注）
5. **Reuse Check** — 与现有代码及其他建模文件的对照
6. **Open Questions** — 需用户确认的点

可选（每章 ≤ 30 行，不计入必填章节的 150 行限制）：
- **State Machine** — 实体或组件有多状态生命周期时填写（states / transitions / guards / actions）
- **Process Model** — 涉及多步操作/条件分支/回滚时填写
- **Component Identification** — 模块涉及多页面/多视图时填写
- **API Surface** — 当模型需要暴露给调用方时补充（伪代码形式）

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"与"复用优先流程"

### 通用检查（所有模式都适用）

- [ ] 每个实体都有需求依据（原文引用或用户动作），不得凭空虚构
- [ ] Open Questions 列出了所有无法独立决定的点，而非强行给出结论

### 内联模式特定检查

- [ ] 产出包含"识别了什么"和"约束是什么"两个维度
- [ ] 产出 10-30 行；超过 30 行应升级到文件级
- [ ] 可追溯性：后续实现代码的结构应体现建模识别的元素（如识别了 3 个状态 → 实现中有对应的状态定义）

### 完整模式特定检查

- [ ] Aggregates 前置章节声明了本单元持有的聚合（或写 Aggregate.none + 理由）
- [ ] 所有数值/时间/状态字段都经过派生性审视，派生关系以等式形式呈现（含视觉领域派生）
- [ ] 每个实体至少识别出一条不变量；若确实没有，必须在该实体下显式写明"无不变量"及理由
- [ ] 跨模块关系 / 不变量 / 实体引用均通过 `upstream-ref` 指向其他建模文件，不在本文件重新定义
- [ ] Reuse Check 中的每个"已有代码"断言都带具体文件路径和符号名，且检查过其他建模文件
- [ ] 必填章节产出 < 150 行，每个可选章节 ≤ 30 行
- [ ] 不含任何可选章节的建模文件仍能通过本检查（可选章节完全可选）

### 增量建模特定检查

- [ ] 已读取现有建模文件完整内容（而非仅看顶部）
- [ ] 已有锚点未被删除或重命名（如需删除必须升级给用户）
- [ ] 新增条目与已有条目不冲突（派生等式不矛盾、不变量不互斥）
- [ ] 增量后整体建模文件仍满足完整模式检查

## 验证方式

### 本 skill 特定验证

1. **反向验证**：读产出的建模文件，能否反推出本单元的核心需求？不能 → 建模不完整
2. **派生验证**：列出的每个字段，调用方只需输入根变量就能推出所有派生值吗？不能 → 还有派生关系被遗漏
3. **复用验证**：Reuse Check 中标记"新建"的条目，确实在项目里搜索过且未找到吗？
4. **跨模块验证**：本建模文件中引用的其他单元实体/锚点确实存在于对方文件吗？
5. **最小性验证**：能否删掉任何一个实体/字段而不影响需求实现？能 → 违反"若无必要勿增实体"
6. **可引用验证**（文件级模式）：产出文档的每个实体、关系、不变量、派生关系、聚合都带 `<!-- anchor: <Namespace>.<Name> -->` HTML 注释形式的显式锚点。**内联模式免除此项**。
7. **可追溯验证**（内联模式）：实现代码的结构是否体现了建模识别的元素？

### 产出即上游契约

`docs/models/<scenario>/<name>.md` 使用 HTML 注释锚点（`<!-- anchor: <Namespace>.<Name> -->`），供下游 skill 通过 `upstream-ref: docs/models/<scenario>/<name>.md#<Namespace>.<Name>` 方式机械引用。

**通用命名空间**（按 scenario 有使用权限差异）：`Aggregate` / `Entity` / `Rel` / `Derivation` / `Invariant` / `StateMachine` / `Process` / `Component`

**例外写法**：`Invariant.<Subject>.none` / `Aggregate.none`（显式标记无内容 + 理由）。`<Subject>` 在 `domain/` / `ui/` / `state-machine/` / `components/` 中通常是实体或组件名；在 `process/` 中可为 `Process` 或被引用实体名。

> 📖 **详细命名空间规范见** `references/anchors.md`：每个 scenario 可用的命名空间清单、跨 scenario 的主权约束、跨模块不变量的 `.cross.<N>` 写法

本 skill 只保证**产出契约**；下游如何消费契约由调用方 skill 自行定义。

## 不覆盖范围

- 不负责需求探索
- 不负责规格化 / 测试 / 实现
- 不做详尽 UML / DDD 级建模（本 skill 只产出**最小可用模型**）

> 跨模块的切分规划**可以**由调用方完成并传入清单；若调用方未切分，本 skill 在"多模块需求的处理"流程中产出切分提议并直接按提议推进，仅在有无法裁决的歧义时才请用户确认。

## 覆盖声明

**v0.3.0**：重构建模单元定义为 `scenario × 业务模块`，产物路径改为 `docs/models/<scenario>/<name>.md`。解除 basename 固定为 `model.md` 的硬约束（下游编排 skill 如 `spec-driven-dev` 需同步适配）。Scenario 固定 5 个（domain/ui/components/process/state-machine），不允许扩展。

**v0.2.0**：移除了 Epic 级轮廓模式和 `epic-model.md` 产物。建模以"建模单元"为组织粒度。

## 下游消费提示

本 skill 的产物作为上游契约供下游消费。典型映射关系：

- **Spec / Scenario 生成**：每条不变量映射到至少一条场景断言；每个派生关系映射到 property-based test（根变量变、派生值跟着变）；每个状态机转换映射到一条场景
- **Test 设计**：Invariants → 不变量测试；Derivations → 计算正确性测试；State Machine → 转换路径覆盖
- **Impl 约束**：Aggregates 决定事务边界；跨模块契约（event/ref/cmd）决定模块间调用方式；派生值不暴露 setter

具体下游工作流（引用规则、CI 校验等）由调用方 skill（如 `spec-driven-dev`）自行定义，本 skill 不越界规定。

## 引用资料

按需读取，不需要一次性全加载。

### 模板

| 文件 | 何时读 |
|------|--------|
| `templates/model.md` | Step 7 完整模式产出时 |

### 规则与规范（references/）

| 文件 | 何时读 |
|------|--------|
| `references/placement.md` | 不确定产物放哪 / 组件归属 / 跨 scenario 规则 / 漂移对齐 |
| `references/anchors.md` | 需要确认某个命名空间的作用域或写法时 |
| `references/cross-module.md` | 处理跨模块关系或跨模块不变量时 |
| `references/anti-patterns.md` | Reuse Check 后 / 产出前自查 |

### 建模步骤（references/steps/，按需精确加载）

| 文件 | 何时读 |
|------|--------|
| `references/steps/step-a.md` | Step 2（识别实体）前 |
| `references/steps/step-a5.md` | Step 3（识别关系/聚合）前 |
| `references/steps/step-b.md` | Step 4（派生关系）前 |
| `references/steps/step-c.md` | Step 5（不变量）前 |
| `references/steps/step-d.md` | Step 4.5（状态机建模）前 |
| `references/steps/step-e.md` | Step 4.5（流程建模）前 |
| `references/steps/step-f.md` | Step 4.6（组件识别）前 |

### 完整示例（examples/，按场景按需加载一个）

| 文件 | 何时读 |
|------|--------|
| `examples/1-backend-domain.md` | 后端领域建模（收藏功能） |
| `examples/2-frontend-interaction.md` | 前端交互建模（拖拽看板） |
| `examples/3-complex-process.md` | 复杂流程建模（多步审批 + 回滚） |
| `examples/4-frontend-cross-page.md` | 前端跨页面建模（会员中心） |
| `examples/5-cross-unit.md` | 跨单元建模（新需求触及多个单元） |
