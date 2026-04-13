---
name: modeling-first
description: "写代码前产出最小领域模型（Epic 用轮廓 epic-model.md，单模块用完整 model.md），避免 LLM 模式匹配式实现。触发词：建模, modeling, 领域模型"
metadata:
  version: 0.1.0
  tags: [modeling, design, architecture, pre-implementation]
---

# Modeling First

> **背景**：LLM 默认用模式匹配方式实现需求（见到"列表页" → 套"表格+分页+筛选"模板），而非建模方式。结果是同一概念多处重复实现、应派生的值被当独立输入、与现有抽象平行新建相似概念。本 skill 强制在写代码前产出**最小领域模型**，把 LLM 从模式匹配切到建模模式。

> **与 `spec-driven-dev` 的关系**：本 skill 是 `spec-driven-dev` 的硬依赖——所有 Epic/模块进入 Plan/Spec 前必须由本 skill 产出 `epic-model.md` / `model.md` 作为领域真理源，下游 `upstream-ref` 均指向本 skill 产出的锚点。本 skill 本身保持为原子 skill，可独立使用；编排由 `spec-driven-dev` 负责，本 skill 不越权。

## 适用场景

判断标准是**需求是否引入新的领域信息**，不是改动范围大小。

**需要建模**（满足任一即触发）：

- 引入**新实体**（新领域概念、新生命周期对象）
- 引入**新关系**（新的实体间关联、新的基数/所有权约定）
- 引入**新不变量**（新的状态机约束、新的合法性规则）
- 引入**新派生关系**（新的计算规则、新的根变量）
- 对现有实体引入**状态变化逻辑**（原本静态，现在有生命周期）

**不需要建模**（直接进入实现）：

- 单函数 bug fix（不改变领域结构）
- 样式调整、文案修改、国际化
- 纯技术重构（重命名、格式化、类型收窄，不改变实体/关系/不变量）
- 对已有实体做**机械性**字段增删（新字段是独立值，不引入派生或不变量）
- 升级依赖、配置变更

**边界情况**：改动范围大但不涉及以上任一"新"的信号 → **不需要建模**；改动范围小但引入新的派生关系 → **需要建模**。看**领域信息增量**，不看**代码行数**。

## 两种建模模式

根据需求规模选择模式。Epic 级需求走**轮廓模式 → 完整模式**两层（先产出 `epic-model.md` 再对每个模块产出 `model.md`）；单模块需求只走完整模式。

| 维度 | 轮廓模式（Outline） | 完整模式（Full） |
|------|-------------------|----------------|
| 触发场景 | Epic / 跨模块 / 涉及多个聚合 | 单模块；或 Epic 拆分后的某个模块 |
| 产出文件 | `epic-model.md` | `<module>/model.md`（走 `spec-driven-dev` 时**必须**用此 basename；独立使用亦可放 `docs/models/<feature>/model.md`）|
| 包含章节 | Context / Entities / Relationships（含聚合边界）/ Shared Invariants | 必填 7 章（Context / Entities / Relationships / Derivation Chains / Invariants / Reuse Check / Open Questions）+ 可选 1 章（API Surface） |
| 不包含 | 派生关系、模块内部不变量、具体 Reuse Check | — |
| 规模 | < 100 行 | < 150 行 |
| 迭代性 | **可迭代**：模块级建模若发现 epic-model 错误，回流修正 | 每个模块内部迭代 |

### 防重复定义

模块级建模必须**引用** epic-model 的共享实体，不得**复制**。

- ✅ 订单模块 `model.md` 写：`User（引用 epic-model.md#Entity.User）`
- ❌ 订单模块 `model.md` 重新定义完整的 `User` 实体

> **本 skill 是原子 skill**：只负责产出建模文件，不负责编排下游流程。若你在 `spec-driven-dev` 等编排型 skill 中调用本 skill，完整工作流（Plan/Spec/Test/Impl/迭代回流规则）由编排 skill 定义，本 skill 不重复声明。

## 必须材料

- 需求描述（来自用户原话、brainstorming 产出、issue 链接之一）
- 能访问项目源代码（用于 Reuse Check）
- 产出目标路径：`<module>/model.md` 或 `docs/models/<feature>/model.md`（走 `spec-driven-dev` 时 basename **必须**为 `model.md` / `epic-model.md`，不得改名；`spec-driven-dev` 的机械校验会直接拒绝其他 basename）

## 执行步骤

### Step 0: 判断模式

先确定走哪种模式：

- 需求是 **Epic**（跨多个模块 / 涉及多个领域聚合）→ **轮廓模式**，用 `templates/epic-model.md`
- 需求是**单模块**（或 Epic 已拆分完、现在处理某个具体模块）→ **完整模式**，用 `templates/model.md`
- 无法判断是否 Epic：用"这个需求需要多少个独立开发的模块才能完成？"试回答，≥ 2 → Epic

**子 Epic（递归）**：若模块级建模时发现本模块自身跨多个聚合且足够复杂，应升级为子 Epic：退出当前完整模式，以本模块为范围启动新一轮轮廓模式，产出 `<module>/epic-model.md`，再对子模块走完整模式。子 Epic 的 epic-model 必须引用上层 epic-model 中的共享实体。递归深度建议 ≤ 2 层；超过说明上层切分过粗。

两种模式的步骤差异：

| 步骤 | 轮廓模式 | 完整模式 |
|------|---------|---------|
| Step 1 判断是否建模 | ✅ | ✅ |
| Step 2 识别实体 | ✅（仅跨模块共享实体） | ✅（全部实体） |
| Step 3 识别关系 | ✅（跨聚合关系 + 聚合边界） | ✅（全部，含聚合内部） |
| Step 4 派生关系 | ❌ 跳过 | ✅ |
| Step 5 识别不变量 | ✅（仅跨聚合/跨模块共享不变量） | ✅（每个实体至少一条） |
| Step 6 Reuse Check | ❌ 跳过（概念层面提示由 Step 7 产出） | ✅（具体文件路径） |
| Step 7 产出文件 | ✅（`epic-model.md`） | ✅（`<module>/model.md`） |
| Step 8 进入下一阶段 | ✅ | ✅ |

### Step 1: 判断是否需要建模

用上面"适用场景"清单对照当前需求。如果明显不需要建模，**直接告知用户跳过本 skill，进入实现**。不要为小改动走完整流程。

### Step 2: 识别实体（从需求中提取名词）

- 读需求原文，把所有名词（含隐含名词）列出
- 去掉技术词（"接口"、"页面"、"组件"），保留领域词（"订单"、"用户"、"权限"）
- 每个实体必须标注**来源**：来自需求原文的哪一句，或对应哪个用户动作

> 📖 **执行此步前先读** `references/modeling-guide.md#step-a`（名词分类、隐含名词、实体识别信号）。

### Step 3: 识别实体间关系（基数与所有权）

对每对相关实体，明确：

- **基数**：1:1 / 1:N / N:N
- **所有权**：谁持有谁（`Order` 持有 `OrderItem`，但 `User` 不"持有" `Order`，而是被关联）
- **聚合边界**：删除上游实体时，下游跟着删 / 保留 / 禁止删除

**关键**：关系决定了数据结构的形状（是引用还是嵌套）、事务边界（何时整体读写）、删除语义（级联 vs 保留）。漏掉关系 = 产出只是名词清单，不是模型。

**轮廓模式的重点**：如果是 Epic 级建模，聚合边界是本步骤的核心产出——下游编排 skill 的模块拆分必须尊重聚合（一个聚合不得跨模块）。模块级建模可以复用这里识别的聚合边界。

> 📖 **执行此步前先读** `references/modeling-guide.md#step-a5`（基数/所有权/聚合边界的 3 个判定问题）。Epic 级建模还需读 `#cross-aggregate-contract`（跨聚合契约线索的填写格式）。

### Step 4: 识别派生关系（等式形式）

> **轮廓模式跳过此步**。派生关系是模块内部细节，epic 级不做。

对所有数值型、时间型、状态型字段，问："这个值能不能从其他值算出来？"

- 能算出来的 → 写成等式：`派生值 = f(根变量1, 根变量2)`
- 算不出来的 → 确认是独立字段

**关键**：派生关系必须是等式或函数，不接受"与 X 有关"这种模糊描述。

> 📖 **执行此步前先读** `references/modeling-guide.md#step-b`（派生三问 + 典型派生模式分类），并对照 `#anti-patterns` 的"反模式 1：派生值被当独立输入"自查。

### Step 5: 识别不变量

对每个实体，问："什么条件在任何时候都必须成立？什么状态是非法的？"

- 用可验证的形式写（`total >= 0`、`email is unique`、`status in [...]`）
- 不变量决定了 API 设计（什么不能暴露给调用方修改）

**轮廓模式只记录"跨聚合/跨模块的共享不变量"**（例如"User.id 全局唯一"）；聚合内部的具体不变量留给模块级建模。

> 📖 **执行此步前先读** `references/modeling-guide.md#step-c`（不变量两问）。轮廓模式还需读 `#invariant-scope`（跨聚合 vs 聚合内判定口诀）。

### Step 6: Reuse Check（对照现有代码）

> **轮廓模式跳过此步**。Reuse Check 是具体文件路径级别的检查，epic 级只做概念层面提示（如"项目已有 auth 模块，新会话逻辑应集成而非重建"），具体搜索留给模块级建模。

对每个实体、每个派生函数、每个工具逻辑：

- 项目里是否已有表达？给出具体文件路径和符号名
- 有 → 决策：复用 / 扩展 / 不复用（说明理由）
- 无 → 决策：新建（说明放置位置）

**关键**：不接受"项目里可能有"、"应该有类似的东西"——必须实际搜索代码并给出路径。

> 📖 **反模式自查**：完成 Reuse Check 后对照 `references/modeling-guide.md#anti-patterns` 的"反模式 4：平行新建"。

### Step 7: 产出建模文件

- **轮廓模式**：按 `templates/epic-model.md` 输出 `epic-model.md`
- **完整模式**：按 `templates/model.md` 输出 `<module>/model.md`（或 `docs/models/<feature>/model.md`）。**basename 固定为 `model.md`**——`spec-driven-dev` 的机械校验只认 `model.md` / `epic-model.md`

提交给用户确认后再进入下一阶段。

### Step 8: 交付产物

本 skill 到此结束——不负责触发或编排下游流程。

- 告知用户产出文件路径（`epic-model.md` 或 `model.md`）
- 列出 Open Questions（如有），等用户确认
- 若调用方是编排型 skill（如 `spec-driven-dev`），产物将被其消费；完整流程的编排、迭代回流规则由调用方定义，本 skill 不越权声明

**迭代内聚**：若执行过程中发现已有 `epic-model.md` 有误（例如模块级建模暴露了聚合划分问题），直接修正该文件——本 skill 只保证建模文件自身的正确性。

## 产物与格式

### 轮廓模式（Epic 用）

见 `templates/epic-model.md`。核心章节：

1. **Context** — Epic 目标 + 来源
2. **Entities** — 跨模块共享实体清单（带需求依据）
3. **Relationships** — 跨模块关系、聚合边界（本模式的核心产出）
4. **Shared Invariants** — 跨聚合/跨模块的共享不变量（聚合内部不变量留给模块级）
5. **Aggregate → Module Mapping**（可选）— 若已有初步 Plan 草稿，标注每个聚合预期落入哪个模块
6. **Open Questions** — 需用户确认的点

### 完整模式（单模块用）

见 `templates/model.md`。必填 7 章 + 可选 1 章：

必填：
1. **Context** — 一句话说明要做什么 + 来源（若本模块属于 Epic，必须引用 epic-model.md）
2. **Entities** — 实体清单（带需求依据，共享实体用"引用 `epic-model.md#Entity.<Name>`"而非重定义）
3. **Relationships** — 实体间的基数、所有权、聚合边界
4. **Derivation Chains** — 派生关系（等式）
5. **Invariants** — 不变量（可验证条件，每个实体至少一条或显式写"无"）
6. **Reuse Check** — 与现有代码对照（带具体路径）
7. **Open Questions** — 需用户确认的点

可选：
- **API Surface** — 当模型需要暴露给调用方时补充（伪代码形式，由项目技术栈决定具体形态）

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"与"复用优先流程"

### 通用检查（两种模式都适用）

- [ ] 每个实体都有需求依据（原文引用或用户动作），不得凭空虚构
- [ ] 已识别聚合边界（每个实体属于哪个聚合）
- [ ] Open Questions 列出了所有无法独立决定的点，而非强行给出结论

### 轮廓模式特定检查

- [ ] 只包含跨模块/跨聚合信息，未下钻到模块内部派生和具体 Reuse 路径
- [ ] 聚合边界清晰，能直接支持下游按聚合切分模块
- [ ] 产出 < 100 行

### 完整模式特定检查

- [ ] 所有数值/时间/状态字段都经过派生性审视，派生关系以等式形式呈现
- [ ] 每个实体至少识别出一条不变量；若确实没有，必须在该实体下显式写明"无不变量"及理由（如"纯数据结构，无状态约束"）
- [ ] Reuse Check 中的每个"已有代码"断言都带具体文件路径和符号名
- [ ] 若本模块属于 Epic，共享实体必须**引用** epic-model，不得重新定义
- [ ] 产出 < 150 行

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定验证

1. **反向验证**：读产出的 `model.md`，能否反推出原始需求的核心？不能 → 建模不完整
2. **派生验证**：列出的每个字段，调用方只需输入根变量就能推出所有派生值吗？不能 → 还有派生关系被遗漏
3. **复用验证**：Reuse Check 中标记"新建"的条目，确实在项目里搜索过且未找到吗？
4. **最小性验证**：能否删掉任何一个实体/字段而不影响需求实现？能 → 违反"若无必要勿增实体"
5. **可引用验证**：产出文档的每个实体、关系、不变量、派生关系、聚合都带 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释形式的显式锚点**（heading / bold / 纯文本都不满足机械校验要求）。锚点是为任何下游编排 skill 提供的机械可校验契约

### 产出即上游契约

`model.md` / `epic-model.md` 使用统一的 HTML 注释锚点（`<!-- anchor: <Namespace>.<Name> -->`），供任何下游 skill 通过 `upstream-ref: <file>#<Namespace>.<Name>` 方式机械引用。锚点命名空间：

- `Entity.<Name>` / `Aggregate.<Name>` / `Rel.<A>-<B>` / `Derivation.<Entity>.<field>` / `Invariant.<Entity>.<N>` / `SharedInvariant.<N>`

本 skill 只保证**产出契约**；下游如何消费契约（Plan/Spec/Test 引用规则、CI 校验脚本等）由调用方 skill 自行定义。

## 不覆盖范围

- 不负责需求探索
- 不负责规格化 / 测试 / 实现
- 不负责编排下游流程（由 `spec-driven-dev` 等编排型 skill 负责）
- 不做详尽 UML / DDD 级建模（本 skill 只产出**最小可用模型**，保持 < 150 行）

## 覆盖声明

无

## 引用资料

| 文件 | 何时读 |
|------|--------|
| `templates/epic-model.md` | Step 7 轮廓模式产出时（必填写前通读一次） |
| `templates/model.md` | Step 7 完整模式产出时（必填写前通读一次） |
| `references/modeling-guide.md#step-a` | Step 2（识别实体）前 |
| `references/modeling-guide.md#step-a5` | Step 3（识别关系/聚合）前 |
| `references/modeling-guide.md#step-b` | Step 4（派生关系）前 |
| `references/modeling-guide.md#step-c` | Step 5（不变量）前 |
| `references/modeling-guide.md#invariant-scope` | 轮廓模式 Step 5（判定跨聚合 vs 聚合内） |
| `references/modeling-guide.md#cross-aggregate-contract` | 轮廓模式 Step 3（填写跨聚合契约线索） |
| `references/modeling-guide.md#anti-patterns` | 验证阶段 / Reuse Check 后自查 |
