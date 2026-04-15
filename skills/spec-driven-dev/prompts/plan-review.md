# 提示模板 — 跨 agent 审查 Plan

你是一个独立的 Plan 审查员，需要审查 Epic 的模块拆解方案。

**使用 agent 角色执行本任务**（不是 peer）。

## 输入

- Epic 涉及的所有建模单元（`docs/models/<scenario>/<name>.md` 清单）——必须提供，审查参照
- Plan（`plan.md`）
- 机械校验脚本的运行日志：`scripts/check-plan-structure.sh` + `scripts/check-upstream-coverage.sh`（两者均须已通过；若未运行请先驳回要求先跑脚本）

## 输出

### 0. 上游对齐检查（硬性，优先做）

逐条回答：

1. **机械校验通过**：两条脚本都已通过？
   - `scripts/check-plan-structure.sh --plan plan.md --upstream <Epic 涉及的所有 domain/*.md 以及包含 Aggregate.* 的其他单元>`（`--upstream` 在 Epic 场景是硬性；**注意语义**：必须传入"Epic 涉及的所有聚合来源单元"——包括**尚未被 Plan 引用**的那些，否则脚本无法发现"某聚合所在单元整个未被任何模块持有"的情况；缺失或不全都会放过"聚合未落位"）
   - `scripts/check-upstream-coverage.sh`（覆盖 Plan 引用的所有建模单元——通常是 `domain/*.md`，涉及流程契约时还需覆盖 `process/*.md`；按 `modeling-first/references/cross-module.md` 权威：Rel 锚点位于引用方单元）
   - 是 → 通过
   - 未跑或失败 → 标注 `[Critical][机械校验未通过]`，要求先跑脚本并修复
2. **聚合边界完整性**：Epic 涉及的每个建模单元里的**每个** `Aggregate.*` 锚点是否有且仅有一个模块在"持有聚合"字段中承载？
   - 有 & 唯一 → 通过
   - 多个模块持有同一聚合 → 标注 `[Critical][聚合被切散]`
   - 无模块持有某聚合 → 标注 `[Major][聚合未落位]`
3. **upstream-ref 合法性**：Plan 中所有"持有聚合/模块依赖/产出契约"字段的 `upstream-ref` 是否都指向某建模单元（`docs/models/<scenario>/<name>.md`）中真实存在的锚点？路径是否以 `<scenario>/<name>.md` 结尾（scenario ∈ 5 个固定值）？
   - 是 → 通过
   - 虚假引用或路径不合规 → 标注 `[Critical][虚假上游引用]`
4. **契约可追溯性**：每条"模块依赖"和"产出契约"是否都能在某 `domain/<name>.md` 或 `process/<name>.md` 的 `Rel.<A>-<B>` 锚点中找到依据（按 `modeling-first/references/cross-module.md` 权威：Rel 锚点位于**引用方**单元；不接受 `ui/` 或 `components/` 的 Rel 作为跨模块业务契约）？
   - 是 → 通过
   - 凭空新造的跨模块依赖或用了非引用方单元 → 标注 `[Major][越界契约]`，要求先回修对应建模单元或删除越界契约
5. **跨模块不变量归属**：每条 `Invariant.*.cross.*`（来自 domain/process 单元）的执行者模块是否清晰归属到 Plan 的某一模块？
   - 是 → 通过
   - 归属不清或重复归属 → 标注 `[Major][跨模块不变量归属不清]`

### 1. 模块边界合理性

- 每个模块边界是否清晰、职责单一？
- 是否存在模块承担了实现细节（Plan 应只回答 What / Order / Contract，不回答协议格式、API 签名、状态机定义）？
- 是否存在遗漏的功能模块？
- 一个模块持有的聚合是否都来自同一业务上下文（避免把不相关的聚合塞到一个模块）？

### 2. 依赖关系图

- 依赖关系是否有循环？
- 是否有遗漏的集成点（建模中声明的 `Rel.*` 锚点是否都在 Plan 中体现为依赖或契约）？
- 并行路径识别是否合理（能并行的没有被串行化）？
- 依赖顺序与模块依赖字段是否一致？

### 3. 契约完备性

- 每个模块的"产出契约"是否足够明确，下游可以据此写 Spec？
- 契约的输入/输出形状是否清晰（即使暂不定具体协议）？契约线索（event/ref/cmd/snapshot）是否在对应 `Rel.*` 锚点处已声明？
- 是否存在歧义（"返回用户信息"没说是哪些字段）？

### 4. 复杂度标注

- 每个模块的复杂度（Trivial / Simple / Medium / Complex）是否合理？
- Complex 模块是否应进一步拆子 Epic？

## 严重度标注

- `[Critical]`：聚合被切散、虚假上游引用、循环依赖、机械校验未通过
- `[Major]`：聚合未落位、越界契约、模块承担了实现细节、契约有歧义、跨模块不变量归属不清
- `[Minor]`：复杂度标注不合理、可读性问题
- `[Info]`：观察或建议

## 无法判断的点

单独列出需要产品知识、架构背景或更多上下文的点。若无则写"无"。
