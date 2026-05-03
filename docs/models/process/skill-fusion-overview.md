# Model — process/skill-fusion-overview

> **此文件存放路径**：`docs/models/process/skill-fusion-overview.md`。本单元建模 Epic `mattpocock-fusion` 涉及的 4 个 skill（debugging / adr-recorder / code-review / modeling-first）之间的边界与契约关系，不是单 skill 内部领域模型。

**Unit**: `process/skill-fusion-overview`
**Context**: 把 mattpocock/skills 的 4 条原则吸收进本仓库 skill 体系——划清 4 个目标 skill 的责任边界、触发词作用域、产物路径独立性、与现有 skill（thinking-guardrails / self-improving）的关系。
**Source**: Epic: mattpocock-fusion (spec-driven-dev auto)；checkpoint Context Summary；本阶段 handoff.md。
**Date**: 2026-05-03

## Aggregates（本单元持有）

<!-- anchor: Aggregate.none -->
- **Aggregate.none** — 理由：本单元为 `process/` scenario，建模主体是"4 个 skill 之间的契约关系"，不持有领域聚合。各 skill 内部产物（ADR 记录、Repro Script 等）的归属由各 skill 在 tech-spec 阶段定义。

---

## 1. Process Units

> **节头说明**:本单元为 `process/` scenario,主体是 skill 流程单位。按 `modeling-first/references/anchors.md` 的 process/ 命名空间清单,每个 skill 单位用 `Process.<Name>` 锚点(`Entity.<Name>` 仅 domain/ui 可用)。Controller 在 modeling-review round 1 裁决:把 4 个 skill 收在同一 process/ 单元里,这是 controller 决策(契约视图集中),`Process.<SkillName>` 是符合 anchors.md 约束的最贴近写法。

<!-- anchor: Process.DebuggingSkill -->
- **DebuggingSkill** — 依据：checkpoint "Epic 目标 → /diagnose 反馈环" + handoff "reproduce → hypothesise → instrument → fix → regress" — **新建** `skills/debugging/` — 触发词：`debug, 调试, 诊断, 复现, repro, feedback loop, 反馈环` — 完成定义：必须落一个 repro-script 或回归测试文件 — 产物路径：`.debug/` + 项目内的 repro 脚本/测试用例

<!-- anchor: Process.AdrRecorderSkill -->
- **AdrRecorderSkill** — 依据：checkpoint "ADR 三条件" + handoff "三条件 AND gate（难逆转 / 没上下文会惊讶 / 真实取舍），script 校验" — **新建** `skills/adr-recorder/` — 触发词：`ADR, architecture decision, 架构决策, 不可逆, 决策记录` — 完成定义：通过 AND gate 后产出一条 ADR — 产物路径：`docs/adr/NNNN-<slug>.md`

<!-- anchor: Process.CodeReviewSkill -->
- **CodeReviewSkill** — 依据：checkpoint "deep module/seam/deletion test" + handoff "扩展 code-review，加'抽象与边界'章节" — **扩展** `skills/code-review/` — 现有触发词不变：`review, code review, 代码审查, 重复检测` — 增量：新增"抽象与边界"小节（deep module / shallow module / seam / deletion test 判断语言）— 产物路径不变：`.code-review/`

<!-- anchor: Process.ModelingFirstSkill -->
- **ModelingFirstSkill** — 依据：handoff "扩展 modeling-first：domain scenario 模板加'已知歧义''反约定'两节；约定 docs/models/INDEX.md 跨 scenario 索引" — **扩展** `skills/modeling-first/` — 触发词不变 — 增量：domain scenario 模板加 2 个 slot + 跨 scenario 索引约定 — 产物路径不变 `docs/models/<scenario>/<name>.md`，新增 `docs/models/INDEX.md`

> 跨单元引用的现有 skill（不在本单元定义新内容，仅用于划清边界）：

<!-- anchor: Process.ThinkingGuardrailsSkill -->
- **ThinkingGuardrailsSkill** — 已存在 `skills/thinking-guardrails/` — 触发词：`thinking, guardrails, 思维守卫, 建模思维, 奥卡姆` — 定位：**编码前置**思维原则包，注入指令文件常驻生效。

<!-- anchor: Process.SelfImprovingSkill -->
- **SelfImprovingSkill** — 已存在 `skills/self-improving/` — 触发词来自 description（self-reflection / corrections / preferences）— 定位：跨会话自我学习与记忆系统（HOT/WARM/COLD 三档）。

---

## 2. Relationships

### 模块内关系（4 个目标 skill 之间）

<!-- anchor: Rel.DebuggingSkill-CodeReviewSkill -->
- **DebuggingSkill ↔ CodeReviewSkill** — N:N — 互不持有/互不调用 — 保留 — 边界：debugging = 运行时表现异常的诊断；code-review = 已写代码的结构性审查。同一 PR 周期可能都触发，编排由用户/上层 workflow 决定，本 Epic 不规定二者顺序。

<!-- anchor: Rel.AdrRecorderSkill-ModelingFirstSkill -->
- **AdrRecorderSkill ↔ ModelingFirstSkill** — N:N — 互不持有 — 保留 — 边界：ADR 是 **point-in-time 决策快照**（归档不演进）；modeling-first 是 **task 级活文档**（持续迭代）。同一议题可能两者都触发，但独立产出、独立生命周期，不双向同步。

<!-- anchor: Rel.CodeReviewSkill-ModelingFirstSkill -->
- **CodeReviewSkill ↔ ModelingFirstSkill** — N:1 引用 — code-review 引用 modeling-first 产物（已存在的"建模对齐检查"，见 `skills/code-review/SKILL.md` Phase 2 第 3 步）— 保留 — 本 Epic 不改这一引用，新增的"抽象与边界"小节也不引入新依赖。

<!-- anchor: Rel.DebuggingSkill-AdrRecorderSkill -->
- **DebuggingSkill ↔ AdrRecorderSkill** — N:N — 互不调用 — 保留 — 边界：debugging 关注"如何复现并修掉 bug"；adr-recorder 关注"为什么做了某个不可逆决定"。bug 修复中产生的"换底层库"等决定**可能**升级触发 adr-recorder，但由用户判断，debugging 不强制调用。

### 跨单元关系（与现有 skill 的边界）

<!-- anchor: Rel.DebuggingSkill-ThinkingGuardrailsSkill -->
- **DebuggingSkill ↔ ThinkingGuardrailsSkill** — N:1 互补 — 不持有 — 保留 — 关键边界：thinking-guardrails = **编码前置**（写代码前的思维守卫，常驻指令文件）；debugging = **运行时事后**（bug 已出现，反馈环优先的诊断流程）。作用阶段不重叠。
  - 契约：`ref: skills/debugging reads no shared state from skills/thinking-guardrails`；触发词集合不相交。

<!-- anchor: Rel.DebuggingSkill-SelfImprovingSkill -->
- **DebuggingSkill ↔ SelfImprovingSkill** — N:1 互补 — 不持有 — 保留 — 关键边界：self-improving = **跨会话**自我反思与长期记忆（HOT/WARM/COLD，3 次晋升）；debugging = **单次诊断闭环**（reproduce → fix → regress，不跨会话累积）。debugging 完成后的经验**可能**被 self-improving 探测器自动捕获，但 debugging 不显式调用。
  - 契约：`event: ReflectionEligibleEvent from skills/debugging → skills/self-improving (via host steering)`；debugging 不直接写入 `~/self-improving/`。

<!-- anchor: Rel.AdrRecorderSkill-ModelingFirstSkill-ambiguity -->
- **AdrRecorderSkill ↔ ModelingFirstSkill（"已知歧义/反约定"slot）** — N:1 引用语义层 — 不持有 — 保留 — 内容关系：modeling-first "已知歧义" = 当前模型的待澄清点（可演进）；ADR = 已做的难逆转决定（不演进）。议题进入 ADR 后应从 slot 移除或标 "resolved by ADR-NNNN"。软约定，本 Epic 不强制 CI 校验。
  - 契约：`event: AdrPublished from skills/adr-recorder → host (consumable by skills/modeling-first via coding agent)`——producer 是 adr-recorder skill,consumer 是宿主 coding agent(由其在后续触发 modeling-first 时刷新对应 model 的歧义 slot),不是 skill→skill 直接订阅。

---

## 3. Derivation Chains

根变量：每个 skill 的**触发词集合 / 完成定义 / 产物路径**——各自独立声明，由各 SKILL.md 主权决定。

<!-- anchor: Derivation.none -->
- **Derivation.none** — 理由：本单元是"边界与契约"层级建模，不存在跨 skill 的派生计算关系；每个 skill 的根变量不能从其他 skill 的属性算出来。反例校验：debugging 的触发词不是 adr-recorder 触发词的函数；code-review 新章节字段不是 modeling-first 模板字段的函数（粒度与对象不同）。不含视觉领域派生（本单元为 process/）。

---

## 4. Invariants

### DebuggingSkill

<!-- anchor: Invariant.DebuggingSkill.1 -->
- skill 完成时必须产出一个 repro-script 或回归测试文件（落到项目工作区，可被后续 CI 拾取）—— 否则视为流程未闭环。

<!-- anchor: Invariant.DebuggingSkill.2 -->
- skill 流程必须按 `reproduce → hypothesise → instrument → fix → regress` 顺序推进，禁止跳过 reproduce 直接进入 fix（无复现 = 无反馈环）。

### AdrRecorderSkill

<!-- anchor: Invariant.AdrRecorderSkill.1 -->
- skill 必须执行三条件 AND gate（难逆转 ∧ 没上下文会惊讶 ∧ 真实取舍）；任一条件不满足时不得产出 ADR 文件，必须显式返回"不该写 ADR"并说明哪一条不满足。

<!-- anchor: Invariant.AdrRecorderSkill.2 -->
- 已发布的 ADR（`docs/adr/NNNN-<slug>.md`）禁止改写决策内容；只允许追加 "Superseded by ADR-MMMM" 标记。

### CodeReviewSkill

<!-- anchor: Invariant.CodeReviewSkill.1 -->
- 新增"抽象与边界"小节聚焦**模块层面**（is this module deep or shallow / is this seam well-placed / does deletion test pass for this abstraction），与已有"模式 5（若无必要勿增实体）/ 模式 6（找到底层规则派生一切）"聚焦的**单个值/字段/参数**层面互补，不重叠。

<!-- anchor: Invariant.CodeReviewSkill.2 -->
- 本 Epic 的扩展不允许移除或重命名 SKILL.md 中已有的 Phase 1 / Phase 2 / Phase 3 编号与现有触发词；只允许在 Phase 2 内追加章节。

### ModelingFirstSkill

<!-- anchor: Invariant.ModelingFirstSkill.1 -->
- "已知歧义"和"反约定"两节是 `domain/` scenario 内部增强，不进入 `process/ui/components/state-machine/` 模板；这两节是**模板可选 slot**（出现时遵循约定写法，不出现时不视为模板违规）。

<!-- anchor: Invariant.ModelingFirstSkill.2 -->
- `docs/models/INDEX.md` 是**跨 scenario 索引**而非建模产物本身，不持有任何锚点（不能被 `upstream-ref` 引用）；本 Epic 的扩展不打破"项目全局视图通过扫描 docs/models/ 聚合得到"这一现状（INDEX.md 为辅助导航，不是 single source of truth）。

### ThinkingGuardrailsSkill / SelfImprovingSkill（上下文引用,内部不变量不在本单元定义）

<!-- anchor: Invariant.ThinkingGuardrailsSkill.none -->
- **Invariant.ThinkingGuardrailsSkill.none** — 理由：本单元仅引用 thinking-guardrails 用于划清 debugging 与"编码前置"的边界,不在本单元定义其内部不变量(已存在于 `skills/thinking-guardrails/SKILL.md`)。本单元承载的边界约束已通过 `Invariant.Process.cross.4` 表达。

<!-- anchor: Invariant.SelfImprovingSkill.none -->
- **Invariant.SelfImprovingSkill.none** — 理由：本单元仅引用 self-improving 用于划清 debugging 与"跨会话自我反思"的边界,不在本单元定义其内部不变量(由 `skills/self-improving/` 自身维护)。本单元承载的边界约束体现在 `Rel.DebuggingSkill-SelfImprovingSkill` 的 event 契约形式中。

### 跨模块不变量（本单元为执行者）

> 本 Epic 范围内 4 个 skill 的 source 都在本同一模型文件，不需要 `upstream-ref` 跨文件引用。以下不变量统一标注 `[跨模块]` 表示**跨 skill 边界**约束，由本单元（process/skill-fusion-overview）作为契约持有者，落地由各 skill 的 SKILL.md 在后续阶段实现。

<!-- anchor: Invariant.Process.cross.1 -->
- **[跨模块] 触发词不冲突**：4 个目标 skill 的触发词集合两两不相交，且与现有 thinking-guardrails / self-improving / modeling-first / code-review 的触发词集合不相交。涉及：§1 全部 6 个 Process Unit。执行者：各 skill 的 SKILL.md frontmatter `description` 在 tech-spec 阶段落地校验，基线为已扫描确认现有 skills 不使用 `debug / 诊断 / 复现 / feedback loop / ADR / architecture decision / 架构决策 / 不可逆` 作为触发词。失败处理：发现冲突 → 升级 Open Question，不允许私自重命名绕过。

<!-- anchor: Invariant.Process.cross.2 -->
- **[跨模块] 责任不重叠**：每个目标 skill 的"完成定义"必须落在本文件 §1 标注的产物上，不得越界。debugging 完成 = repro-script 或回归测试 ≠ ADR / model.md / review-report.md；adr-recorder 完成 = `docs/adr/NNNN-<slug>.md` ≠ 其他三类；code-review 扩展只改 `skills/code-review/`；modeling-first 扩展只改 `skills/modeling-first/templates/*` + `docs/models/INDEX.md`。涉及：§1 全部 4 个目标 Process Unit。执行者：feature-implementation 阶段按各 skill 的 Allowed Write Scope 落实。失败处理：越界写入 → review 判 fail。

<!-- anchor: Invariant.Process.cross.3 -->
- **[跨模块] 生命周期独立**：debugging → `.debug/` + 项目内 repro 脚本/测试；adr-recorder → `docs/adr/`（git 内）；code-review → `.code-review/`（已存在）；modeling-first → `docs/models/`（已存在）+ 新增 `docs/models/INDEX.md`。涉及：§1 全部 4 个目标 Process Unit。执行者：tech-spec 阶段在各 skill 的"产物与格式"章节落地。失败处理：发现路径冲突 → 升级 Open Question。

<!-- anchor: Invariant.Process.cross.4 -->
- **[跨模块] debugging vs thinking-guardrails 边界互斥**：debugging 不得在其触发词或完成定义中纳入 thinking-guardrails 已覆盖的"编码前置"语义（建模思维 / 奥卡姆剃刀的写代码前检查清单）。涉及：`Process.DebuggingSkill / Process.ThinkingGuardrailsSkill`。执行者：debugging 的 SKILL.md 显式声明"运行时诊断流程，不替代编码前置守卫"。失败处理：tech-spec review 发现越界 → 退回。

<!-- anchor: Invariant.Process.cross.5 -->
- **[跨模块] adr-recorder vs modeling-first 时间语义互斥**：ADR 是 point-in-time 快照，modeling-first 是活文档；adr-recorder 不得引入"修改已发布 ADR 决策内容"或"同步刷新 ADR 追上 model.md"的机制。涉及：`Process.AdrRecorderSkill / Process.ModelingFirstSkill`。执行者：adr-recorder 的 SKILL.md 写明"已发布 ADR 不可改，新决定写新 ADR 并 supersede 旧 ADR"。失败处理：tech-spec 中出现 ADR 回流机制 → 退回。

<!-- anchor: Invariant.Process.cross.6 -->
- **[跨模块] code-review "抽象与边界" vs 已有"模式 5/6"粒度互斥**：新章节聚焦**模块层面**（deep / shallow module / seam / deletion test），已有规则聚焦**单值/字段/参数层面**（若无必要勿增实体 / 派生根变量）；不允许新章节复述已有规则。涉及：`Process.CodeReviewSkill`（含与 thinking-guardrails 注入到 CLAUDE.md 的"奥卡姆剃刀"互斥）。执行者：tech-spec 阶段显式列出新章节判断语言。失败处理：发现复述 → 退回。

---

## 5. Reuse Check

| 需要的能力 | 已有代码（实际路径） | 决策 | 理由 |
|-----------|--------------------|------|------|
| `debugging` skill | 已搜索 `ls skills/`，无 | 新建 `skills/debugging/` | 不存在 |
| `adr-recorder` skill | 已搜索 `ls skills/`，无 | 新建 `skills/adr-recorder/` | 不存在 |
| code-review "抽象与边界" 章节 | `skills/code-review/SKILL.md` Phase 2 第 3 步只覆盖单值层面（模式 5/6），无模块层面 | 扩展 | Phase 2 内追加新章节 |
| modeling-first "已知歧义/反约定" slot | `skills/modeling-first/templates/model.md` 现有章节无此 slot；SKILL.md "项目全局视图"段显式说"通过扫描聚合，不靠单一索引" | 扩展 + 新增 | 模板加 2 个 slot；新增 `docs/models/INDEX.md` 作为辅助导航（非 SoT） |
| 触发词冲突检测 | `grep "debug\|诊断\|复现\|feedback loop\|ADR\|architecture decision\|架构决策\|不可逆" skills/*/SKILL.md` 仅命中 `multi-agent-loop/SKILL.md:106` 正文，非触发词 | 复用 grep | 不需新建工具 |
| `docs/models/process/skill-fusion-overview.md` | 同目录有 `spec-driven-dev.md`，无本文件 | 新建 | 路径不冲突 |
| code-review "建模对齐检查" 现有机制 | `skills/code-review/SKILL.md` Phase 2 第 3 步已实现对 modeling-first 的引用 | 保留不动 | 本 Epic 不改 |
| `docs/adr/` 目录 | `ls docs/` 仅有 `models/`，无 `adr/` | 新建（adr-recorder 实现阶段） | 路径不冲突 |
| `.debug/` 目录 | repo 根 `ls -la` 未见 | 新建（debugging 实现阶段） | 路径不冲突 |

---

## 6. Open Questions

- [ ] `docs/models/INDEX.md` 的具体生成机制（手工维护 / 脚本扫描 / CI 检查）由 modeling-first 扩展的 tech-spec 阶段决定，本建模阶段不锁定。
- [ ] debugging skill 的反馈环 5 步（reproduce → hypothesise → instrument → fix → regress）每步是否都强制产出一个工件，还是仅 reproduce 与 regress 强制？由 debugging 的 tech-spec 阶段决定。
- [ ] adr-recorder 的"三条件 AND gate"由 script 校验还是 LLM 自检？由 adr-recorder 的 tech-spec 阶段决定。
- [ ] code-review 新章节"抽象与边界"是否需要新增 jscpd-style 自动化检测脚本，还是纯 LLM 判断（与现有"模式 5/6"对齐）？由 code-review 扩展的 tech-spec 阶段决定。

---

<details>
<summary>📎 (可选) Process Model — 4 个 skill 的运行期触发与产物链路</summary>

> 仅描述本 Epic 落地后用户使用这 4 个 skill 时的典型流程链路，非编排约束（spec-driven-dev 不强制串联）。

<!-- anchor: Process.SkillTriggerFlow -->
```
Trigger sources:
  - 用户写代码前  → thinking-guardrails (常驻指令文件，自动生效)
  - 用户写代码前需建新模型 → modeling-first
  - 用户做架构决定        → adr-recorder (三条件 AND gate)
  - 用户代码运行异常      → debugging (reproduce → hypothesise → instrument → fix → regress)
  - 用户对已有代码做审查  → code-review (Phase 1 jscpd → Phase 2 LLM 含"抽象与边界")
  - 用户多会话累积经验    → self-improving (跨会话晋升 HOT)
Concurrency: 各 skill 独立触发，不互相阻塞；同一 PR 周期内可多次触发不同 skill。
Rollback: 各 skill 自身的失败处理由各 SKILL.md 定义；本 Epic 不引入跨 skill 回滚。
```

</details>
