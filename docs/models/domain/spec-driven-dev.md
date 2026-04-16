# Model — domain/spec-driven-dev

**Unit**: `domain/spec-driven-dev`
**Context**: `spec-driven-dev` 作为前置编排器的稳定领域概念： intake、澄清、建模、plan 与 handoff
**Source**: 用户原话“spec-driven-dev: 先完成建模和 plan” + “使用 spec-driven-dev skill: 编写 plan, 完成后 multi-agent-loop 启动 codex 审查”
**Date**: 2026-04-16

## Aggregates（本单元持有）

<!-- anchor: Aggregate.WorkflowRun -->
- **WorkflowRun Aggregate** — 根实体：`WorkflowRun` — 内部实体：`ClarifiedRequirement`, `ModelingBundle`, `PlanArtifact`, `HandoffPacket`, `ReviewRound`

---

## 1. Entities

<!-- anchor: Entity.WorkflowRun -->
- **WorkflowRun** — 需求依据：`spec-driven-dev` 负责把一次需求从 intake 推进到建模完成、必要时产出 plan，并把结果交给下游 skill（位置：`skills/spec-driven-dev/SKILL.md`）

<!-- anchor: Entity.ClarifiedRequirement -->
- **ClarifiedRequirement** — 需求依据：模糊需求需要先补全问题、假设、范围和未决点，形成澄清后的需求基线，才进入建模（位置：计划中的 `requirements-clarification` 技能边界）

<!-- anchor: Entity.ModelingBundle -->
- **ModelingBundle** — 需求依据：`spec-driven-dev` 的核心职责之一是调用 `modeling-first`，产出可供下游引用的 `docs/models/<scenario>/<name>.md` 集合（位置：`docs/models/`）

<!-- anchor: Entity.PlanArtifact -->
- **PlanArtifact** — 需求依据：Epic / 多模块需求在进入后续技术文档阶段前必须先有模块边界、依赖关系和契约（位置：`spec/*.md`）

<!-- anchor: Entity.HandoffPacket -->
- **HandoffPacket** — 需求依据：`spec-driven-dev` 结束时要交付给下游的不是代码，而是 requirement baseline、模型清单、可选的 plan 以及可选的 `review notes`（位置：下游 skill 的输入协议）

<!-- anchor: Entity.ReviewRound -->
- **ReviewRound** — 需求依据：plan 完成后可通过 `multi-agent-loop` 启动独立 agent 做结构化审查（位置：`.agent-loop/` 会话协议）

---

## 2. Relationships

<!-- anchor: Rel.WorkflowRun-ClarifiedRequirement -->
- **WorkflowRun ↔ ClarifiedRequirement** — 1:0..1 — 仅当原始需求不清晰时才持有澄清后的需求基线；该产物属于当前 WorkflowRun

<!-- anchor: Rel.WorkflowRun-ModelingBundle -->
- **WorkflowRun ↔ ModelingBundle** — 1:1 — 每个 WorkflowRun 都必须产出或更新 ModelingBundle

<!-- anchor: Rel.WorkflowRun-PlanArtifact -->
- **WorkflowRun ↔ PlanArtifact** — 1:0..1 — 单模块场景可无 PlanArtifact；Epic / 多模块场景必须有

<!-- anchor: Rel.WorkflowRun-HandoffPacket -->
- **WorkflowRun ↔ HandoffPacket** — 1:1 — WorkflowRun 结束时输出一个 HandoffPacket，供下游 `tech-spec-writing` 消费

<!-- anchor: Rel.WorkflowRun-ReviewRound -->
- **WorkflowRun ↔ ReviewRound** — 1:N — WorkflowRun 可在 plan 完成后发起多轮独立审查；ReviewRound 不脱离 WorkflowRun 存在

---

## 3. Derivation Chains

### 根变量（调用方实际需要输入的）

- `WorkflowRun.mode: 'standard' | 'auto'`
- `WorkflowRun.scope: 'single-module' | 'epic'`
- `WorkflowRun.requirementClarity: 'clear' | 'vague'`
- `WorkflowRun.reviewRequested: boolean`

### 派生值（不作为独立输入）

<!-- anchor: Derivation.WorkflowRun.requiresClarification -->
- `WorkflowRun.requiresClarification = (requirementClarity == 'vague')` — 派生位置：前置 intake 判定

<!-- anchor: Derivation.WorkflowRun.requiresPlan -->
- `WorkflowRun.requiresPlan = (scope == 'epic')` — 派生位置：`skills/spec-driven-dev/SKILL.md`

<!-- anchor: Derivation.WorkflowRun.reviewAgent -->
- `WorkflowRun.reviewAgent = if reviewRequested then 'multi-agent-loop/<selected-runner>' else 'none'` — 派生位置：controller 调度

<!-- anchor: Derivation.WorkflowRun.handoffReady -->
- `WorkflowRun.handoffReady = models_ready && (!requiresPlan || plan_ready)` — 派生位置：`spec-driven-dev` 结束前门禁

---

## 4. Invariants

### WorkflowRun

<!-- anchor: Invariant.WorkflowRun.1 -->
- `mode in {'standard', 'auto'}`

<!-- anchor: Invariant.WorkflowRun.2 -->
- `scope in {'single-module', 'epic'}`

<!-- anchor: Invariant.WorkflowRun.3 -->
- `每个 WorkflowRun 都必须完成建模；不得跳过 ModelingBundle 直接产出 HandoffPacket`

<!-- anchor: Invariant.WorkflowRun.4 -->
- `scope == 'epic' → PlanArtifact 在 HandoffPacket 生成前必须存在`

### HandoffPacket

<!-- anchor: Invariant.HandoffPacket.1 -->
- `HandoffPacket 至少包含 requirement baseline 与 ModelingBundle；Epic 还必须包含 PlanArtifact；若 reviewRequested == true 则追加 review notes`

<!-- anchor: Invariant.HandoffPacket.2 -->
- `HandoffPacket 不包含技术文档、测试代码或功能实现代码`

### ReviewRound

<!-- anchor: Invariant.ReviewRound.1 -->
- `reviewRequested == true → ReviewRound 必须通过独立 agent 执行，不得用当前会话自审冒充`

---

## 5. Reuse Check

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 前置编排入口 | `skills/spec-driven-dev/SKILL.md` | 复用 | 已有 mode / scope / plan 语义 |
| 建模能力 | `skills/modeling-first/SKILL.md` | 复用 | 已是稳定上游依赖 |
| 独立审查编排 | `skills/multi-agent-loop/SKILL.md` | 复用 | 已支持 codex 独立审查 |
| 后续 spec/test/impl 顶级 skill | `skills/tech-spec-writing/SKILL.md`, `skills/test-design-and-implementation/SKILL.md` | 部分复用 | 技术文档与测试顶级 skill 已实现，功能实现 skill 仍待补齐 |

---

## 6. Open Questions

- [ ] `requirements-clarification` 是完全独立顶级 skill，还是允许 `spec-driven-dev` 在 trivial 场景内联处理极少量补问？
- [ ] `spec-driven-dev` 的输出是否需要一个显式 handoff 模板文件，还是只用 plan + model 清单即可？

---

## State Machine — WorkflowRun.Preparation

<!-- anchor: StateMachine.WorkflowRun.Preparation -->
```text
States: intake | clarification | modeling | planning | review | handoff | done | blocked
Transitions:
  intake → clarification   guard: requiresClarification   action: collect ClarifiedRequirement
  intake → modeling        guard: !requiresClarification  action: start modeling-first
  clarification → modeling guard: clarification complete  action: start modeling-first
  modeling → planning      guard: requiresPlan            action: draft plan
  modeling → handoff       guard: !requiresPlan           action: assemble handoff packet
  planning → review        guard: reviewRequested         action: launch independent review
  planning → handoff       guard: !reviewRequested        action: assemble handoff packet
  review → handoff         guard: review resolved         action: update plan and assemble handoff packet
  handoff → done           guard: handoffReady           action: expose downstream inputs
  any → blocked            guard: missing required inputs action: surface blocker
```
