# Model — domain/skill-delivery-architecture

**Unit**: `domain/skill-delivery-architecture`
**Context**: 顶级 skill 拆分后的交付架构：由 `spec-driven-dev` 统一编排需求澄清、建模、plan、技术文档、测试和实现
**Source**: 用户原话“想把 spec-driven-dev 变成一个流程编排的 skill” + “--auto 还是自动推进模式” + “spec-driven-dev 不在维护各阶段的详细内容模板”
**Date**: 2026-04-16

## Aggregates（本单元持有）

<!-- anchor: Aggregate.RequirementsClarificationSkill -->
- **RequirementsClarificationSkill Aggregate** — 根实体：`RequirementsClarificationSkill` — 内部实体：`ClarifiedRequirement`

<!-- anchor: Aggregate.SpecDrivenDevSkill -->
- **SpecDrivenDevSkill Aggregate** — 根实体：`SpecDrivenDevSkill` — 内部实体：`ModelingBundle`, `PlanArtifact`, `StageHandoff`, `WorkflowCheckpoint`, `ReviewRound`

<!-- anchor: Aggregate.TechSpecWritingSkill -->
- **TechSpecWritingSkill Aggregate** — 根实体：`TechSpecWritingSkill` — 内部实体：`TechnicalSpec`

<!-- anchor: Aggregate.TestDesignAndImplementationSkill -->
- **TestDesignAndImplementationSkill Aggregate** — 根实体：`TestDesignAndImplementationSkill` — 内部实体：`ExecutableTestSuite`

<!-- anchor: Aggregate.FeatureImplementationFromSpecSkill -->
- **FeatureImplementationFromSpecSkill Aggregate** — 根实体：`FeatureImplementationFromSpecSkill` — 内部实体：`DeliveredChange`

---

## 1. Entities

<!-- anchor: Entity.RequirementsClarificationSkill -->
- **RequirementsClarificationSkill** — 需求依据：模糊需求先转成明确需求与未决点清单，再交给流程编排器继续推进

<!-- anchor: Entity.SpecDrivenDevSkill -->
- **SpecDrivenDevSkill** — 需求依据：作为规范驱动开发的总入口，负责编排 clarification、modeling、plan、tech spec、test、implementation 和 verification

<!-- anchor: Entity.TechSpecWritingSkill -->
- **TechSpecWritingSkill** — 需求依据：把完整需求与模型/plan 翻译成技术文档

<!-- anchor: Entity.TestDesignAndImplementationSkill -->
- **TestDesignAndImplementationSkill** — 需求依据：根据技术文档设计测试场景并实现测试

<!-- anchor: Entity.FeatureImplementationFromSpecSkill -->
- **FeatureImplementationFromSpecSkill** — 需求依据：根据技术文档与测试用例完成功能开发并交付可追溯结果

<!-- anchor: Entity.ClarifiedRequirement -->
- **ClarifiedRequirement** — 需求澄清阶段的正式交付物

<!-- anchor: Entity.StageHandoff -->
- **StageHandoff** — `spec-driven-dev` 在阶段间传递的编排级 contract，只描述来源产物、目标 worker 和已确认输入边界

<!-- anchor: Entity.WorkflowCheckpoint -->
- **WorkflowCheckpoint** — `spec-driven-dev` 用于断点续接、阶段 gate 和 `--auto` 推进的流程状态摘要

<!-- anchor: Entity.TechnicalSpec -->
- **TechnicalSpec** — 技术文档阶段的正式交付物；使用稳定章节名组织内容，供下游通过 `spec-ref` 做最小追溯

<!-- anchor: Entity.ExecutableTestSuite -->
- **ExecutableTestSuite** — 测试设计与实现阶段的正式交付物；`Ready for implementation` 分支中的测试必须带 `Scenario ID` 与 `@scenario` / `@spec-ref` 最小追溯

<!-- anchor: Entity.ReviewRound -->
- **ReviewRound** — 独立审查轮次；在架构层代表 `spec-driven-dev` 对 `multi-agent-loop` 的阶段性调用

<!-- anchor: Entity.DeliveredChange -->
- **DeliveredChange** — 功能实现阶段的正式交付物；至少包含 `Spec Completeness Matrix`、`Upstream Coverage Matrix`、`Validation`、`Blockers`、`Unfinished Items`、`Residual Risks` 和 `Status`

---

## 2. Relationships

<!-- anchor: Rel.RequirementsClarification-SpecDrivenDev -->
- **RequirementsClarificationSkill ↔ SpecDrivenDevSkill** — 1:0..1 — 仅当原始需求模糊时，`ClarifiedRequirement` 才交给 `spec-driven-dev` 做后续编排

<!-- anchor: Rel.SpecDrivenDev-TechSpecWriting -->
- **SpecDrivenDevSkill ↔ TechSpecWritingSkill** — 1:1 — `spec-driven-dev` 在完成建模与必要的 plan 后，将阶段 handoff 路由给 `tech-spec-writing`

<!-- anchor: Rel.TechSpecWriting-TestDesign -->
- **TechSpecWritingSkill ↔ TestDesignAndImplementationSkill** — 1:1 — 技术文档是测试设计与实现的直接输入

<!-- anchor: Rel.TechSpecWriting-FeatureImplementation -->
- **TechSpecWritingSkill ↔ FeatureImplementationFromSpecSkill** — 1:1 — 功能实现必须消费批准后的 TechnicalSpec

<!-- anchor: Rel.TestDesign-FeatureImplementation -->
- **TestDesignAndImplementationSkill ↔ FeatureImplementationFromSpecSkill** — 1:1 — 功能实现必须消费已实现的 ExecutableTestSuite

<!-- anchor: Rel.FeatureImplementation-DeliveredChange -->
- **FeatureImplementationFromSpecSkill ↔ DeliveredChange** — 1:1 — 功能实现输出 traceable DeliveredChange

---

## 3. Derivation Chains

### 根变量（调用方实际需要输入的）

- `requirementClarity`
- `scope`
- `technicalSpecApproved`
- `testSuiteReady`
- `modelConstraintsReady`
- `blockingQuestionsResolved`
- `domainCoverageReady`
- `workflowMode`

### 派生值（不作为独立输入）

<!-- anchor: Derivation.SkillFlow.needsClarification -->
- `SkillFlow.needsClarification = (requirementClarity == 'vague')`

<!-- anchor: Derivation.SkillFlow.needsPlan -->
- `SkillFlow.needsPlan = (scope == 'epic')`

<!-- anchor: Derivation.SkillFlow.autoDrivesStages -->
- `SkillFlow.autoDrivesStages = (workflowMode == 'auto')`

<!-- anchor: Derivation.SkillFlow.implementationReady -->
- `SkillFlow.implementationReady = technicalSpecApproved && testSuiteReady && modelConstraintsReady && blockingQuestionsResolved && domainCoverageReady`

---

## 4. Invariants

<!-- anchor: Invariant.RequirementsClarificationSkill.1 -->
- `RequirementsClarificationSkill 不直接产出模型、技术文档、测试代码或实现代码`

<!-- anchor: Invariant.SpecDrivenDevSkill.1 -->
- `SpecDrivenDevSkill 保留完整流程入口与阶段 gate，但不深度维护 clarification / tech spec / test / implementation 的详细内容模板`

<!-- anchor: Invariant.SpecDrivenDevSkill.2 -->
- `SpecDrivenDevSkill 在 --auto 模式下可自动推进全流程，但各阶段正式产物仍必须由对应 worker skill 生成`

<!-- anchor: Invariant.SpecDrivenDevSkill.3 -->
- `SpecDrivenDevSkill 的编排产物只包括 StageHandoff、WorkflowCheckpoint、PlanArtifact、ReviewRound 等 orchestration-specific 信息，不越界伪造 TechnicalSpec、ExecutableTestSuite 或 DeliveredChange`

<!-- anchor: Invariant.TechSpecWritingSkill.1 -->
- `TechSpecWritingSkill 不直接实现测试代码或功能代码`

<!-- anchor: Invariant.TestDesignAndImplementationSkill.1 -->
- `TestDesignAndImplementationSkill 不重新定义需求或技术文档语义`

<!-- anchor: Invariant.TestDesignAndImplementationSkill.2 -->
- `TestDesignAndImplementationSkill 在 Ready for implementation 分支中产出的 ExecutableTestSuite 必须带 Scenario ID 与 @scenario / @spec-ref 最小追溯`

<!-- anchor: Invariant.FeatureImplementationFromSpecSkill.1 -->
- `FeatureImplementationFromSpecSkill 必须同时消费批准后的 TechnicalSpec 与 ExecutableTestSuite，并在存在上游建模约束时对相关 docs/models/<scenario>/<name>.md 进行实现追溯`

<!-- anchor: Invariant.FeatureImplementationFromSpecSkill.2 -->
- `FeatureImplementationFromSpecSkill 只有在 Blocking Questions 已清零、每个声明的 spec 功能域都有对应可执行测试时，才允许进入 Delivered 分支`

<!-- anchor: Invariant.DeliveredChange.1 -->
- `DeliveredChange 必须包含 Spec Completeness Matrix、Upstream Coverage Matrix、Validation、Blockers、Unfinished Items、Residual Risks 和 Status`

<!-- anchor: Invariant.DeliveredChange.2 -->
- `Status == Delivered 时，Spec Completeness Matrix 中每个功能域都必须有真实测试证据，Upstream Coverage Matrix 必须保留精确的 Scenario ID（或显式 N/A）与 spec-ref`

---

## 5. Reuse Check

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 总流程编排入口 | `skills/spec-driven-dev/SKILL.md` | 收缩复用 | 保留总入口与 `--auto`，下放阶段细则 |
| 需求澄清顶级 skill | `skills/requirements-clarification/SKILL.md` | 复用 | 当前仓库已实现 |
| 技术文档顶级 skill | `skills/tech-spec-writing/SKILL.md` | 复用 | 当前仓库已实现 |
| 测试设计与实现顶级 skill | `skills/test-design-and-implementation/SKILL.md` | 复用 | 当前仓库已实现 |
| 按 spec 实现顶级 skill | `skills/feature-implementation-from-spec/SKILL.md` | 复用 | 当前仓库已实现 |
| 建模与独立审查原子依赖 | `skills/modeling-first/SKILL.md`, `skills/multi-agent-loop/SKILL.md` | 复用 | orchestrator 的上游硬依赖 |

---

## 6. Open Questions

- [ ] orchestration-specific `StageHandoff` / `WorkflowCheckpoint` 是否要抽成共享编排协议，供其他 workflow skill 复用？
- [ ] `DeliveredChange` 是否需要在未来固定落盘到某个标准路径（例如 `docs/deliveries/`），还是继续允许作为自由格式的交付报告存在？
