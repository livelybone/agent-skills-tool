# Model — domain/skill-delivery-architecture

**Unit**: `domain/skill-delivery-architecture`
**Context**: 顶级 skill 拆分后的交付架构：需求澄清、建模与 plan、技术文档、测试、实现
**Source**: 用户原话“假设现在没有 spec-driven-dev...这些都可以是顶级的 skill 吧?” + “spec-driven-dev: 先完成建模和 plan”
**Date**: 2026-04-16

## Aggregates（本单元持有）

<!-- anchor: Aggregate.RequirementsClarificationSkill -->
- **RequirementsClarificationSkill Aggregate** — 根实体：`RequirementsClarificationSkill` — 内部实体：`ClarifiedRequirement`

<!-- anchor: Aggregate.SpecDrivenDevSkill -->
- **SpecDrivenDevSkill Aggregate** — 根实体：`SpecDrivenDevSkill` — 内部实体：`ModelingBundle`, `PlanArtifact`, `HandoffPacket`, `ReviewRound`

<!-- anchor: Aggregate.TechSpecWritingSkill -->
- **TechSpecWritingSkill Aggregate** — 根实体：`TechSpecWritingSkill` — 内部实体：`TechnicalSpec`

<!-- anchor: Aggregate.TestDesignAndImplementationSkill -->
- **TestDesignAndImplementationSkill Aggregate** — 根实体：`TestDesignAndImplementationSkill` — 内部实体：`ExecutableTestSuite`

<!-- anchor: Aggregate.FeatureImplementationFromSpecSkill -->
- **FeatureImplementationFromSpecSkill Aggregate** — 根实体：`FeatureImplementationFromSpecSkill` — 内部实体：`DeliveredChange`

---

## 1. Entities

<!-- anchor: Entity.RequirementsClarificationSkill -->
- **RequirementsClarificationSkill** — 需求依据：模糊需求先转成明确需求与未决点清单，再交给下游

<!-- anchor: Entity.SpecDrivenDevSkill -->
- **SpecDrivenDevSkill** — 需求依据：完成建模和 plan，并把结果 handoff 给下游技术文档阶段

<!-- anchor: Entity.TechSpecWritingSkill -->
- **TechSpecWritingSkill** — 需求依据：把完整需求与模型/plan 翻译成技术文档

<!-- anchor: Entity.TestDesignAndImplementationSkill -->
- **TestDesignAndImplementationSkill** — 需求依据：根据技术文档设计测试场景并实现测试

<!-- anchor: Entity.FeatureImplementationFromSpecSkill -->
- **FeatureImplementationFromSpecSkill** — 需求依据：根据技术文档与测试用例完成需求开发

<!-- anchor: Entity.ClarifiedRequirement -->
- **ClarifiedRequirement** — 需求澄清阶段的正式交付物

<!-- anchor: Entity.TechnicalSpec -->
- **TechnicalSpec** — 技术文档阶段的正式交付物

<!-- anchor: Entity.ExecutableTestSuite -->
- **ExecutableTestSuite** — 测试设计与实现阶段的正式交付物

<!-- anchor: Entity.HandoffPacket -->
- **HandoffPacket** — `spec-driven-dev` 向 `tech-spec-writing` 交付的 requirement baseline + models + optional plan + optional review notes 包

<!-- anchor: Entity.ReviewRound -->
- **ReviewRound** — 独立审查轮次；在架构层代表 `spec-driven-dev` 对 `multi-agent-loop` 的可选调用

<!-- anchor: Entity.DeliveredChange -->
- **DeliveredChange** — 功能实现阶段的正式交付物

---

## 2. Relationships

<!-- anchor: Rel.RequirementsClarification-SpecDrivenDev -->
- **RequirementsClarificationSkill ↔ SpecDrivenDevSkill** — 1:0..1 — 仅当原始需求模糊时，`ClarifiedRequirement` 才交给 `spec-driven-dev` 做建模与 plan

<!-- anchor: Rel.SpecDrivenDev-TechSpecWriting -->
- **SpecDrivenDevSkill ↔ TechSpecWritingSkill** — 1:1 — `spec-driven-dev` 的 requirement baseline + ModelingBundle + optional PlanArtifact + optional review notes handoff 给 `tech-spec-writing`

<!-- anchor: Rel.TechSpecWriting-TestDesign -->
- **TechSpecWritingSkill ↔ TestDesignAndImplementationSkill** — 1:1 — 技术文档是测试设计与实现的直接输入

<!-- anchor: Rel.TechSpecWriting-FeatureImplementation -->
- **TechSpecWritingSkill ↔ FeatureImplementationFromSpecSkill** — 1:1 — 功能实现必须消费批准后的 TechnicalSpec

<!-- anchor: Rel.TestDesign-FeatureImplementation -->
- **TestDesignAndImplementationSkill ↔ FeatureImplementationFromSpecSkill** — 1:1 — 功能实现必须消费已实现的 ExecutableTestSuite

<!-- anchor: Rel.FeatureImplementation-DeliveredChange -->
- **FeatureImplementationFromSpecSkill ↔ DeliveredChange** — 1:1 — 功能实现输出 DeliveredChange

---

## 3. Derivation Chains

### 根变量（调用方实际需要输入的）

- `requirementClarity`
- `scope`
- `technicalSpecApproved`
- `testSuiteReady`

### 派生值（不作为独立输入）

<!-- anchor: Derivation.SkillFlow.needsClarification -->
- `SkillFlow.needsClarification = (requirementClarity == 'vague')`

<!-- anchor: Derivation.SkillFlow.needsPlan -->
- `SkillFlow.needsPlan = (scope == 'epic')`

<!-- anchor: Derivation.SkillFlow.implementationReady -->
- `SkillFlow.implementationReady = technicalSpecApproved && testSuiteReady`

---

## 4. Invariants

<!-- anchor: Invariant.RequirementsClarificationSkill.1 -->
- `RequirementsClarificationSkill 不直接产出模型、技术文档、测试代码或实现代码`

<!-- anchor: Invariant.SpecDrivenDevSkill.1 -->
- `SpecDrivenDevSkill 结束于 HandoffPacket（其中至少包含 requirement baseline、ModelingBundle，Epic 额外包含 PlanArtifact；存在独立审查时可包含 review notes）；不得向下越界编写 TechnicalSpec、ExecutableTestSuite 或 DeliveredChange`

<!-- anchor: Invariant.TechSpecWritingSkill.1 -->
- `TechSpecWritingSkill 不直接实现测试代码或功能代码`

<!-- anchor: Invariant.TestDesignAndImplementationSkill.1 -->
- `TestDesignAndImplementationSkill 不重新定义需求或技术文档语义`

<!-- anchor: Invariant.FeatureImplementationFromSpecSkill.1 -->
- `FeatureImplementationFromSpecSkill 必须同时消费批准后的 TechnicalSpec 与 ExecutableTestSuite`

---

## 5. Reuse Check

| 需要的能力 | 已有代码（项目中实际路径） | 决策 | 理由 |
|-----------|--------------------------|------|------|
| 建模与 plan 顶级能力 | `skills/spec-driven-dev/SKILL.md` | 收缩复用 | 保留为前置编排器 |
| 需求澄清顶级 skill | 无（已搜索 `skills/*/SKILL.md`） | 新建 | 当前仓库缺失 |
| 技术文档顶级 skill | 无（已搜索 `skills/*/SKILL.md`） | 新建 | 当前仓库缺失 |
| 测试设计与实现顶级 skill | 无（已搜索 `skills/*/SKILL.md`） | 新建 | 当前仓库缺失 |
| 按 spec 实现顶级 skill | 无（已搜索 `skills/*/SKILL.md`） | 新建 | 当前仓库缺失 |

---

## 6. Open Questions

- [ ] `upstream-contracts` 是否在这轮 Epic 中单独成 skill，还是先继续留在 `tech-spec-writing` / `test-design-and-implementation` 的共享协议里？
- [ ] `requirements-clarification` 的输出是自由文档，还是也要有固定模板？
