# Model — domain/spec-driven-dev

**Unit**: `domain/spec-driven-dev`
**Context**: `spec-driven-dev` 作为规范驱动开发总入口的稳定领域概念： intake、按需澄清、建模、plan、tech spec、test、implementation、verification 的流程编排
**Source**: 用户原话“现在 spec-driven-dev 相当于 all in one” + “想把 spec-driven-dev 变成一个流程编排的 skill” + “--auto 还是自动推进模式”
**Date**: 2026-04-16

## Aggregates（本单元持有）

<!-- anchor: Aggregate.WorkflowRun -->
- **WorkflowRun Aggregate** — 根实体：`WorkflowRun` — 内部实体：`ClarifiedRequirement`, `ModelingBundle`, `PlanArtifact`, `StageHandoff`, `WorkflowCheckpoint`, `ReviewRound`

---

## 1. Entities

<!-- anchor: Entity.WorkflowRun -->
- **WorkflowRun** — 需求依据：`spec-driven-dev` 负责把一次需求从 intake 一直编排到 tech spec、test、implementation 和 verification，并在各阶段之间维护 route / gate / rollback / checkpoint（位置：`skills/spec-driven-dev/SKILL.md`）

<!-- anchor: Entity.ClarifiedRequirement -->
- **ClarifiedRequirement** — 需求依据：模糊需求需要先补全问题、假设、范围和未决点，形成澄清后的需求基线，才进入建模（位置：计划中的 `requirements-clarification` 技能边界）

<!-- anchor: Entity.ModelingBundle -->
- **ModelingBundle** — 需求依据：`spec-driven-dev` 的核心职责之一是调用 `modeling-first`，产出可供下游引用的 `docs/models/<scenario>/<name>.md` 集合（位置：`docs/models/`）

<!-- anchor: Entity.PlanArtifact -->
- **PlanArtifact** — 需求依据：Epic / 多模块需求在进入后续技术文档阶段前必须先有模块边界、依赖关系和契约（位置：`spec/*.md`）

<!-- anchor: Entity.StageHandoff -->
- **StageHandoff** — 需求依据：`spec-driven-dev` 作为 controller，需要在阶段间传递已确认的输入边界和上游产物，但这些 handoff 只承载编排语义，不重新定义 worker 自己的内容模板

<!-- anchor: Entity.WorkflowCheckpoint -->
- **WorkflowCheckpoint** — 需求依据：总入口 orchestrator 需要记录当前阶段、上一步完成情况和续接摘要，使标准模式与 `--auto` 都能从中断点继续

<!-- anchor: Entity.ReviewRound -->
- **ReviewRound** — 需求依据：任一阶段在需要独立第二视角时，可通过 `multi-agent-loop` 启动独立 agent 做结构化审查（位置：`.agent-loop/` 会话协议）

---

## 2. Relationships

<!-- anchor: Rel.WorkflowRun-ClarifiedRequirement -->
- **WorkflowRun ↔ ClarifiedRequirement** — 1:0..1 — 仅当原始需求不清晰时才持有澄清后的需求基线；该产物属于当前 WorkflowRun

<!-- anchor: Rel.WorkflowRun-ModelingBundle -->
- **WorkflowRun ↔ ModelingBundle** — 1:1 — 每个 WorkflowRun 都必须产出或更新 ModelingBundle

<!-- anchor: Rel.WorkflowRun-PlanArtifact -->
- **WorkflowRun ↔ PlanArtifact** — 1:0..1 — 单模块场景可无 PlanArtifact；Epic / 多模块场景必须有

<!-- anchor: Rel.WorkflowRun-StageHandoff -->
- **WorkflowRun ↔ StageHandoff** — 1:N — WorkflowRun 在各阶段边界都会生成 handoff；同一 run 内会有多次 stage handoff，分别供下游 worker 消费

<!-- anchor: Rel.WorkflowRun-WorkflowCheckpoint -->
- **WorkflowRun ↔ WorkflowCheckpoint** — 1:N — WorkflowRun 在每个阶段完成后都要更新 checkpoint；checkpoint 不脱离当前 run 存在

<!-- anchor: Rel.WorkflowRun-ReviewRound -->
- **WorkflowRun ↔ ReviewRound** — 1:N — WorkflowRun 可在任一高风险阶段发起多轮独立审查；ReviewRound 不脱离 WorkflowRun 存在

---

## 3. Derivation Chains

### 根变量（调用方实际需要输入的）

- `WorkflowRun.mode: 'standard' | 'auto'`
- `WorkflowRun.scope: 'single-module' | 'epic'`
- `WorkflowRun.requirementClarity: 'clear' | 'vague'`
- `WorkflowRun.reviewRequested: boolean`
- `WorkflowRun.currentStage: 'intake' | 'clarification' | 'modeling' | 'planning' | 'tech-spec' | 'test' | 'implementation' | 'verification'`

### 派生值（不作为独立输入）

<!-- anchor: Derivation.WorkflowRun.requiresClarification -->
- `WorkflowRun.requiresClarification = (requirementClarity == 'vague')` — 派生位置：前置 intake 判定

<!-- anchor: Derivation.WorkflowRun.requiresPlan -->
- `WorkflowRun.requiresPlan = (scope == 'epic')` — 派生位置：`skills/spec-driven-dev/SKILL.md`

<!-- anchor: Derivation.WorkflowRun.reviewAgent -->
- `WorkflowRun.reviewAgent = if reviewRequested then 'multi-agent-loop/<selected-runner>' else 'none'` — 派生位置：controller 调度

<!-- anchor: Derivation.WorkflowRun.autoProgressesEndToEnd -->
- `WorkflowRun.autoProgressesEndToEnd = (mode == 'auto')` — 派生位置：`spec-driven-dev` 的自动推进判定

<!-- anchor: Derivation.WorkflowRun.nextStage -->
- `WorkflowRun.nextStage = f(currentStage, requirementClarity, scope, stage_gates)` — 派生位置：controller 的阶段路由

<!-- anchor: Derivation.WorkflowRun.workflowComplete -->
- `WorkflowRun.workflowComplete = verification_complete && delivered_change_ready` — 派生位置：总流程结束门禁

---

## 4. Invariants

### WorkflowRun

<!-- anchor: Invariant.WorkflowRun.1 -->
- `mode in {'standard', 'auto'}`

<!-- anchor: Invariant.WorkflowRun.2 -->
- `scope in {'single-module', 'epic'}`

<!-- anchor: Invariant.WorkflowRun.3 -->
- `每个 WorkflowRun 都必须完成建模；不得跳过 ModelingBundle 直接进入 tech spec / test / implementation 阶段`

<!-- anchor: Invariant.WorkflowRun.4 -->
- `scope == 'epic' → PlanArtifact 在进入 tech spec 阶段前必须存在`

<!-- anchor: Invariant.WorkflowRun.5 -->
- `spec-driven-dev 保留完整流程入口与阶段 gate，但 clarification / technical spec / test / implementation 的详细内容模板必须由对应 worker skill 持有，而非在 orchestrator 中重复维护`

<!-- anchor: Invariant.WorkflowRun.6 -->
- `mode == 'auto'` 时允许自动推进到最终交付，但每个阶段产物仍必须由对应 worker skill 生成，不得由 orchestrator 冒充阶段 worker

### StageHandoff

<!-- anchor: Invariant.StageHandoff.1 -->
- `每个 StageHandoff 必须显式标明当前阶段、来源产物和目标 worker；不得把 worker 自己的内容模板内联复制到 orchestrator contract 中`

<!-- anchor: Invariant.StageHandoff.2 -->
- `StageHandoff 只封装阶段边界与已确认输入，不直接包含技术文档、测试代码或功能实现代码本身`

### WorkflowCheckpoint

<!-- anchor: Invariant.WorkflowCheckpoint.1 -->
- `每个阶段完成后必须更新 WorkflowCheckpoint；缺 checkpoint 不允许宣称该阶段已完成`

### ReviewRound

<!-- anchor: Invariant.ReviewRound.1 -->
- `reviewRequested == true → ReviewRound 必须通过独立 agent 执行，不得用当前会话自审冒充`

---

## 5. Reuse Check

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 总流程编排入口 | `skills/spec-driven-dev/SKILL.md` | 收缩复用 | 保留总入口与 `--auto`，但下放阶段细则 |
| 需求澄清 worker | `skills/requirements-clarification/SKILL.md` | 复用 | 已拆出独立澄清阶段 |
| 建模能力 | `skills/modeling-first/SKILL.md` | 复用 | 已是稳定上游依赖 |
| 技术文档 worker | `skills/tech-spec-writing/SKILL.md` | 复用 | 已拆出独立 spec 阶段 |
| 测试设计与实现 worker | `skills/test-design-and-implementation/SKILL.md` | 复用 | 已拆出独立 test 阶段 |
| 功能实现 worker | `skills/feature-implementation-from-spec/SKILL.md` | 复用 | 已拆出独立 implementation 阶段 |
| 独立审查编排 | `skills/multi-agent-loop/SKILL.md` | 复用 | 已支持 codex 独立审查 |

---

## 6. Open Questions

- [ ] orchestration-specific `StageHandoff` 是否需要单独模板文件，还是只作为 `spec-driven-dev` 的轻量 contract 段落存在？
- [ ] `WorkflowCheckpoint` 应保留在 orchestrator 自身模板中，还是拆成可被其他 workflow skill 复用的共享编排协议？

---

## State Machine — WorkflowRun.Orchestration

<!-- anchor: StateMachine.WorkflowRun.Orchestration -->
```text
States: intake | clarification | modeling | planning | tech-spec | test | implementation | verification | done | blocked
Transitions:
  intake → clarification   guard: requiresClarification   action: collect ClarifiedRequirement
  intake → modeling        guard: !requiresClarification  action: start modeling-first
  clarification → modeling guard: clarification complete  action: start modeling-first
  modeling → planning      guard: requiresPlan            action: draft or update plan
  modeling → tech-spec     guard: !requiresPlan           action: route stage handoff to tech-spec-writing
  planning → tech-spec     guard: plan accepted           action: route stage handoff to tech-spec-writing
  planning → review        guard: reviewRequested         action: launch independent review
  review → planning        guard: review findings reopen plan action: update plan and checkpoint
  review → tech-spec       guard: review resolved         action: route stage handoff to tech-spec-writing
  tech-spec → test         guard: technical spec ready    action: route approved spec to test-design-and-implementation
  test → implementation    guard: test suite ready        action: route tests and spec to feature-implementation-from-spec
  implementation → verification guard: change delivered   action: run final workflow verification and summarize
  verification → done      guard: workflowComplete        action: expose final workflow outcome
  any → blocked            guard: missing required inputs action: surface blocker
```
