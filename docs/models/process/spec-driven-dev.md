# Model — process/spec-driven-dev

**Unit**: `process/spec-driven-dev`
**Context**: `spec-driven-dev` 的前置编排流程： intake、按需澄清、建模、plan、独立审查、handoff
**Source**: 用户原话“spec-driven-dev: 先完成建模和 plan” + “使用 spec-driven-dev skill: 编写 plan, 完成后 multi-agent-loop 启动 codex 审查”
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
| HandoffPacket | 下游消费的 handoff 包 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.HandoffPacket` |
| ReviewRound | 独立审查轮次 | `upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.ReviewRound` |

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
- **SpecDrivenProcess ↔ multi-agent-loop** — 1:0..1 — 当用户要求独立审查时，流程通过 `multi-agent-loop` 启动 `codex` 或其他 runner 审查 plan
  - 契约：`cmd: process/spec-driven-dev calls multi-agent-loop(agent=codex for requested plan review)`
  - 契约：`event: ReviewCompleted from multi-agent-loop → process/spec-driven-dev`

<!-- anchor: Rel.Process-TechSpecWriting -->
- **SpecDrivenProcess ↔ `docs/models/domain/skill-delivery-architecture.md#Entity.TechSpecWritingSkill`** — 1:1 — 流程结束时向 `tech-spec-writing` 交付 HandoffPacket，而不是继续自己写技术文档
  - 契约：`event: HandoffReady from process/spec-driven-dev → tech-spec-writing`
  - 契约：`snapshot: HandoffPacket contains requirement baseline, models, optional plan, optional review notes`

---

## 3. Derivation Chains

### 根变量（调用方实际需要输入的）

- `WorkflowRun.requirementClarity`
- `WorkflowRun.scope`
- `WorkflowRun.reviewRequested`

### 派生值（不作为独立输入）

<!-- anchor: Derivation.Process.entryPath -->
- `Process.entryPath = if requirementClarity == 'vague' then 'clarify-first' else 'model-first'` — 派生位置：intake 判定

<!-- anchor: Derivation.Process.requiresPlan -->
- `Process.requiresPlan = (scope == 'epic')` — 派生位置：`docs/models/domain/spec-driven-dev.md#Derivation.WorkflowRun.requiresPlan`

<!-- anchor: Derivation.Process.reviewRunner -->
- `Process.reviewRunner = if reviewRequested then 'codex via multi-agent-loop' else 'none'` — 派生位置：controller 调度

---

## 4. Invariants

<!-- anchor: Invariant.Process.1 -->
- `在任何 handoff 之前，必须先完成建模`

<!-- anchor: Invariant.Process.2 -->
- `Epic / 多模块场景必须先有 PlanArtifact，才允许 handoff`

<!-- anchor: Invariant.Process.3 -->
- `spec-driven-dev 在本流程中不负责产出技术文档、测试代码或功能实现代码`

<!-- anchor: Invariant.Process.4 -->
- `独立审查被请求时，必须通过 multi-agent-loop 启动独立 runner；不得以内联自审替代`

---

## 5. Reuse Check

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 建模编排 | `skills/spec-driven-dev/SKILL.md`, `skills/spec-driven-dev/workflows/epic.md` | 复用 | 已有建模与 plan 主路径 |
| 建模执行 | `skills/modeling-first/SKILL.md` | 复用 | 上游原子 skill |
| 独立审查执行 | `skills/multi-agent-loop/SKILL.md` | 复用 | 支持 codex 审查 |
| 下游 handoff 消费方 | 无（已搜索 `skills/*/SKILL.md`） | 新建 | 需引入 `tech-spec-writing` 等顶级 skill |

---

## 6. Open Questions

- [ ] 单模块但高复杂度的场景是否也允许生成轻量 plan，还是严格只有 Epic 才产出 plan？
- [ ] `review notes` 的最小结构是否要标准化（例如 findings / resolution / residual-risk 三段），还是先保持自由文本？

---

## Process Model — spec-driven-dev pre-dev path（本单元核心产出）

<!-- anchor: Process.SpecDrivenPreparation -->
```text
Steps:
  1. intake_request        → classify clarity and scope
  2. clarify_if_needed     → produce ClarifiedRequirement
  3. run_modeling_first    → produce ModelingBundle
  4. draft_plan_if_epic    → produce PlanArtifact
  5. review_if_requested   → launch independent codex review via multi-agent-loop
  6. assemble_handoff      → produce HandoffPacket for tech-spec-writing
Rollback:
  - clarification changes invalidate current modeling draft
  - modeling changes invalidate current plan draft
  - review findings reopen the plan before handoff
Concurrency:
  - none inside one WorkflowRun
```
