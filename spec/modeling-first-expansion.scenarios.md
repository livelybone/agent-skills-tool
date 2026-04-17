> ⚠️ **DEPRECATED / 历史档案**：对应 v1.5 spec，部分场景（涉及 epic-model.md / 轮廓模式 / SharedInvariant 等）已在 v2 架构重构中作废。保留作为历史记录。

# Scenarios: modeling-first skill 扩展

## R1: 建模词汇表扩展

[UNIT] SKILL.md 的建模模式表中列出状态机建模维度，含适用信号和核心产出
→ 读者能判断何时启用状态机建模

[UNIT] SKILL.md 的建模模式表中列出流程建模维度，含适用信号和核心产出
→ 读者能判断何时启用流程建模

[UNIT] SKILL.md 的建模模式表中列出组件识别建模维度，含适用信号和核心产出
→ 读者能判断何时启用组件识别

[UNIT] modeling-guide.md 包含视觉领域派生模式的说明
→ 视觉领域派生归入已有 Derivation Chains 方法论，不新建独立章节

[UNIT] modeling-guide.md 中状态机建模方法论包含：识别信号、核心产出格式（states/transitions/guards/actions）、与实体-关系四件套的配合方式
→ 方法论可操作，不仅是概念罗列

[UNIT] modeling-guide.md 中流程建模方法论包含：识别信号、核心产出格式（steps/conditions/branching/rollback）
→ 方法论可操作

[UNIT] modeling-guide.md 中组件识别方法论包含：横向扫描步骤、识别标准、产出格式
→ 方法论可操作

[UNIT] model.md 模板包含可选的"State Machine"章节，含 states/transitions/guards/actions 结构
→ 建模时有结构化位置放置状态机分析

[UNIT] model.md 模板包含可选的"Process Model"章节，含 steps/conditions/branching 结构
→ 建模时有结构化位置放置流程分析

[UNIT] model.md 模板的 Derivation Chains 章节包含视觉领域子类别占位
→ 视觉派生有明确的归属位置

## R2: 内联建模模式

[UNIT] SKILL.md 的建模模式表中包含内联模式（Inline），含适用条件和产出格式
→ 与 outline/full 并列，形成三级体系

[CRITICAL][UNIT] 内联模式定义了最小结构要求（"识别了什么" + "约束是什么"）
→ 内联产出不会退化为无结构的自由文本

[UNIT] 内联模式明确免除锚点要求
→ 不与现有质量门槛的"可引用验证"冲突

[UNIT] 质量门槛章节新增"内联模式特定检查"
→ 内联模式有独立的验证标准

## R3: 建模深度判断逻辑

[CRITICAL][UNIT] SKILL.md 的"适用场景"章节从二分（建模/跳过）改为三级（跳过/内联/文件级）
→ agent 读此章节后能确定任务应走哪一级

[UNIT] 判断信号表覆盖后端、前端、流程三个领域
→ 不同领域的任务都有对应的判断路径

[UNIT] 前端场景细化：纯视觉调整（颜色、字号）→ 跳过；涉及状态或约束 → 内联或更高
→ "样式调整"不再一刀切归为跳过

[UNIT] SKILL.md 包含对编排 skill 的建议（默认调用 modeling-first），但不强制
→ skill 保持原子性

## R4: 触发信号扩展

[UNIT] SKILL.md "需要建模"清单包含前端触发信号（多状态组件、步骤序列交互、布局联动、跨页面视觉重复）
→ 前端任务不会因触发信号缺失而被误判为"不需要建模"

[UNIT] SKILL.md "需要建模"清单包含流程触发信号（多步操作、条件分支、并发/竞态、回滚/补偿）
→ 复杂业务流程不会被误判

[UNIT] SKILL.md "不需要建模"清单包含"纯视觉调整"
→ 跳过条件明确覆盖前端低复杂度场景

## R5: 组件识别

[CRITICAL][UNIT] model.md 模板包含可选的"Component Identification"章节，含组件名、出现位置、输入接口草稿
→ 建模时有结构化位置放置组件识别结果

[UNIT] epic-model.md 模板包含可选的"共享组件识别"章节
→ Epic 级建模能识别跨模块共享组件

[UNIT] 组件识别标准使用需求/设计层面语言（视觉结构、交互模式、数据形状），不使用实现层面概念（DOM、props）
→ 建模阶段可执行，不预设实现

[UNIT] 组件识别明确定位在 Reuse Check 之前
→ 两者的关系和执行顺序清晰

## R6: 非 CRUD 示例

[CRITICAL][UNIT] modeling-guide.md 包含至少一个完整的前端交互建模示例
→ 示例覆盖：触发信号 → 深度选择 → 建模产出 → 指导实现

[CRITICAL][UNIT] modeling-guide.md 包含至少一个完整的复杂流程建模示例
→ 示例覆盖：触发信号 → 深度选择 → 建模产出 → 指导实现

[UNIT] 新示例与现有 CRUD 示例（收藏文章）在同一章节中，形成对比参考
→ 读者能看到不同领域的建模差异

## R7: 向后兼容

[CRITICAL][UNIT] 现有必填章节（Context/Entities/Relationships/Derivation Chains/Invariants/Reuse Check/Open Questions）在 model.md 中保持不变
→ 已有的 model.md 产出仍然有效

[UNIT] 现有锚点命名空间（Entity/Aggregate/Rel/Derivation/Invariant/SharedInvariant）保持不变
→ 下游 upstream-ref 引用不受影响

[UNIT] 新增可选章节使用与现有锚点系统兼容的格式
→ 如 `<!-- anchor: StateMachine.<Entity>.<State> -->`

## R8: 行数约束

[UNIT] 行数限制规则明确：必填章节 outline < 100, full < 150；可选章节不计入，但每个可选章节 ≤ 30 行
→ 质量门槛可机械校验

## 边界场景

[UNIT] 当任务同时涉及新实体和状态机时（如"新增带审批流的订单类型"），建模指引清晰说明如何组合使用实体建模 + 状态机建模
→ 多维度组合使用有指导，不产生歧义

[UNIT] 当内联模式的建模产出超过 30 行时，SKILL.md 有明确指引升级到文件级
→ 内联模式有溢出处理机制

[UNIT] 当任务涉及 3+ 关系或跨模块关注点时，判断逻辑指向文件级（即使实体数量少）
→ 内联模式不会被误用于复杂场景

[UNIT] 仅满足组件识别三标准中的一项时，不合并为共享组件
→ 识别标准有下限，不过度合并

[UNIT] 内联建模的可追溯性规则已文档化：实现代码结构必须体现建模识别的元素
→ 内联模式虽无文件产出，仍有质量约束

[UNIT] 不含任何可选章节的 model.md 仍能通过质量门槛校验
→ 向后兼容：旧格式 model.md 不受影响
