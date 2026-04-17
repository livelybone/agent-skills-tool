# Model — process/spec-driven-dev

**Unit**: `process/spec-driven-dev`
**Context**: `spec-driven-dev` 的完整流程编排： intake、按需澄清、建模、plan、独立审查、tech spec、test、implementation、verification
**Source**: 用户原话“想把 spec-driven-dev 变成一个流程编排的 skill” + “--auto 还是自动推进模式”
**Date**: 2026-04-16

## Aggregates（本单元持有）

<!-- anchor: Aggregate.none -->
- 非 domain 单元，不持有业务聚合。流程依赖的稳定概念通过 `upstream-ref` 引用。

---

## 1. Entities

| 实体 | 依据 | 位置 |
|------|------|------|
| WorkflowRun | 流程主上下文 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.WorkflowRun` |
| ClarifiedRequirement | 模糊需求的补全产物 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.ClarifiedRequirement` |
| ModelingBundle | 建模产物集合 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.ModelingBundle` |
| PlanArtifact | Epic / 多模块 plan 产物 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.PlanArtifact` |
| StageHandoff | 阶段间 handoff contract | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.StageHandoff` |
| WorkflowCheckpoint | 断点续接与 gate 摘要 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.WorkflowCheckpoint` |
| ReviewRound | 独立审查轮次 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.ReviewRound` |
| TechnicalSpec | 技术文档阶段正式产物 | `upstream-ref: docs/models/domain/skill-delivery-architecture.md#Entity.TechnicalSpec` |
| ExecutableTestSuite | 测试阶段正式产物 | `upstream-ref: docs/models/domain/skill-delivery-architecture.md#Entity.ExecutableTestSuite` |
| DeliveredChange | 实现阶段正式交付物 | `upstream-ref: docs/models/domain/skill-delivery-architecture.md#Entity.DeliveredChange` |

---

## 2. Relationships

### 跨单元关系（契约线索）

<!-- anchor: Rel.Process-RequirementsClarification -->
- **SpecDrivenProcess ↔ `docs/models/domain/skill-delivery-architecture.md#Entity.RequirementsClarificationSkill`** — 1:0..1 — 当原始需求模糊时，流程调用 `requirements-clarification` 获取 ClarifiedRequirement
  - 契约：`cmd: process/spec-driven-dev calls requirements-clarification when requirementClarity == 'vague'`
  - 契约：`event: ClarificationReady from requirements-clarification → process/spec-driven-dev`

<!-- anchor: Rel.Process-ModelingFirst -->
- **SpecDrivenProcess ↔ modeling-first** — 1:N — 每个 WorkflowRun 都必须调用 `modeling-first` 产出或更新 `docs/models/<scenario>/<name>.md`
  - 契约：`cmd: process/spec-driven-dev calls modeling-first(full|incremental|multi-unit)`
  - 契约：`ref: process/spec-driven-dev reads docs/models/<scenario>/<name>.md anchors`

<!-- anchor: Rel.Process-MultiAgentLoop -->
- **SpecDrivenProcess ↔ multi-agent-loop** — 1:0..N — 当用户要求独立审查时，流程通过 `multi-agent-loop` 启动 `codex` 或其他 runner 审查当前阶段产物
  - 契约：`cmd: process/spec-driven-dev calls multi-agent-loop(agent=codex for requested stage review)`
  - 契约：`event: ReviewCompleted from multi-agent-loop → process/spec-driven-dev`

<!-- anchor: Rel.Process-TechSpecWriting -->
- **SpecDrivenProcess ↔ `docs/models/domain/skill-delivery-architecture.md#Entity.TechSpecWritingSkill`** — 1:1 — 到达 tech spec 阶段时，流程将当前已确认输入通过 StageHandoff 路由给 `tech-spec-writing`
  - 契约：`cmd: process/spec-driven-dev routes StageHandoff to tech-spec-writing`
  - 契约：`event: TechnicalSpecReady from tech-spec-writing → process/spec-driven-dev`

<!-- anchor: Rel.Process-TestDesignAndImplementation -->
- **SpecDrivenProcess ↔ `docs/models/domain/skill-delivery-architecture.md#Entity.TestDesignAndImplementationSkill`** — 1:1 — tech spec 完成后，流程将批准的 TechnicalSpec 路由给 `test-design-and-implementation`
  - 契约：`cmd: process/spec-driven-dev routes approved TechnicalSpec to test-design-and-implementation`
  - 契约：`event: ExecutableTestSuiteReady from test-design-and-implementation → process/spec-driven-dev`

<!-- anchor: Rel.Process-FeatureImplementation -->
- **SpecDrivenProcess ↔ `docs/models/domain/skill-delivery-architecture.md#Entity.FeatureImplementationFromSpecSkill`** — 1:1 — 测试完成后，流程将 TechnicalSpec + ExecutableTestSuite 路由给 `feature-implementation-from-spec`
  - 契约：`cmd: process/spec-driven-dev routes TechnicalSpec + ExecutableTestSuite to feature-implementation-from-spec`
  - 契约：`event: DeliveredChangeReady from feature-implementation-from-spec → process/spec-driven-dev`

---

## 3. Derivation Chains

### 根变量（调用方实际需要输入的）

- `WorkflowRun.requirementClarity`
- `WorkflowRun.scope`
- `WorkflowRun.reviewRequested`
- `WorkflowRun.currentStage`

### 派生值（不作为独立输入）

<!-- anchor: Derivation.Process.entryPath -->
- `Process.entryPath = if requirementClarity == 'vague' then 'clarify-first' else 'model-first'` — 派生位置：intake 判定

<!-- anchor: Derivation.Process.requiresPlan -->
- `Process.requiresPlan = (scope == 'epic')` — 派生位置：`docs/models/domain/spec-driven-dev.md#Derivation.WorkflowRun.requiresPlan`

<!-- anchor: Derivation.Process.reviewRunner -->
- `Process.reviewRunner = if reviewRequested then 'codex via multi-agent-loop' else 'none'` — 派生位置：controller 调度

<!-- anchor: Derivation.Process.nextWorker -->
- `Process.nextWorker = f(currentStage, scope, reviewRequested)` — 派生位置：orchestrator 的阶段路由

---

## 4. Invariants

<!-- anchor: Invariant.Process.1 -->
- `在进入 tech spec / test / implementation 任何下游阶段前，必须先完成建模`

<!-- anchor: Invariant.Process.2 -->
- `Epic / 多模块场景必须先有 PlanArtifact，才允许进入 tech spec 阶段`

<!-- anchor: Invariant.Process.3 -->
- `spec-driven-dev 在本流程中负责阶段编排与 gate，不负责深度产出技术文档、测试代码或功能实现代码`

<!-- anchor: Invariant.Process.4 -->
- `独立审查被请求时，必须通过 multi-agent-loop 启动独立 runner；不得以内联自审替代`

<!-- anchor: Invariant.Process.5 -->
- `--auto` 仍表示自动推进模式，但自动推进必须通过调用对应 worker skill 完成各阶段，不得由 orchestrator 直接吞掉 worker 边界`

<!-- anchor: Invariant.Process.6 -->
- `阶段详细内容模板应由对应 worker skill 维护；spec-driven-dev 只保留 orchestration-specific contract 和 checkpoint 协议`

---

## 5. Reuse Check

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 总流程编排 | `skills/spec-driven-dev/SKILL.md`, `skills/spec-driven-dev/workflows/epic.md` | 收缩复用 | 保留入口、步骤顺序、gate 与回退 |
| 澄清阶段 worker | `skills/requirements-clarification/SKILL.md` | 复用 | 已拆出独立 worker |
| 建模执行 | `skills/modeling-first/SKILL.md` | 复用 | 上游原子 skill |
| 独立审查执行 | `skills/multi-agent-loop/SKILL.md` | 复用 | 支持 codex 审查 |
| 技术文档 worker | `skills/tech-spec-writing/SKILL.md` | 复用 | 已拆出独立 worker |
| 测试阶段 worker | `skills/test-design-and-implementation/SKILL.md` | 复用 | 已拆出独立 worker |
| 实现阶段 worker | `skills/feature-implementation-from-spec/SKILL.md` | 复用 | 已拆出独立 worker |

---

## 6. Open Questions

- [ ] 单模块但高复杂度的场景是否也允许生成轻量 plan，还是严格只有 Epic 才产出 plan？
- [ ] orchestration-specific `WorkflowCheckpoint` / `StageHandoff` 是否需要共享模板，还是继续仅在 orchestrator 内部约束？

---

## Process Model — spec-driven-dev orchestration path（本单元核心产出）

<!-- anchor: Process.SpecDrivenPreparation -->
```text
Steps:
  1. intake_request        → classify clarity and scope
  2. clarify_if_needed     → produce ClarifiedRequirement
  3. run_modeling_first    → produce ModelingBundle
  4. draft_plan_if_epic    → produce PlanArtifact
  5. review_if_requested   → launch independent stage review via multi-agent-loop
  6. route_tech_spec       → call tech-spec-writing
  7. route_test_stage      → call test-design-and-implementation
  8. route_implementation  → call feature-implementation-from-spec
  9. verify_and_summarize  → update WorkflowCheckpoint and finish run
Rollback:
  - clarification changes invalidate current modeling draft
  - modeling changes invalidate current plan draft
  - plan or review changes invalidate downstream tech spec draft
  - tech spec changes invalidate downstream test and implementation drafts
  - test changes can reopen implementation stage
Concurrency:
  - none inside one WorkflowRun
```
