# Plan — skill-delivery-architecture

**Context**: 将当前偏胖的 `spec-driven-dev` 重构为“前置编排器”，并拆出澄清、技术文档、测试、实现四个顶级 skill
**Source**: 当前对话中用户确认的目标边界：`spec-driven-dev` 只完成建模和 plan；plan 完成后支持独立 codex 审查；后续 spec/test/impl 提升为顶级 skill
**Modeling Units**:
- `docs/models/domain/spec-driven-dev.md`
- `docs/models/process/spec-driven-dev.md`
- `docs/models/domain/skill-delivery-architecture.md`

**Date**: 2026-04-16

---

## Module: requirements-clarification

- **持有聚合**：RequirementsClarificationSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.RequirementsClarificationSkill)
- **边界**：把模糊需求收敛为可执行需求、假设、未决点和范围说明，不进入建模或实现
- **模块依赖**：无
- **产出契约**：向 `spec-driven-dev` 交付 ClarifiedRequirement handoff (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.RequirementsClarification-SpecDrivenDev)
- **复杂度**：Medium

## Module: tech-spec-writing

- **持有聚合**：TechSpecWritingSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.TechSpecWritingSkill)
- **边界**：把完整需求和前置 handoff contract 翻译成技术文档，不直接生成测试或代码
- **模块依赖**：目标运行时依赖 `spec-driven-dev` 的 requirement baseline + models + optional plan + optional review notes handoff (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.SpecDrivenDev-TechSpecWriting)
- **产出契约**：向 `test-design-and-implementation` 交付 approved technical spec (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-TestDesign)
- **产出契约**：向 `feature-implementation-from-spec` 交付 approved technical spec (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-FeatureImplementation)
- **复杂度**：Medium

## Module: test-design-and-implementation

- **持有聚合**：TestDesignAndImplementationSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.TestDesignAndImplementationSkill)
- **边界**：根据技术文档生成测试场景并实现测试，不承担功能代码开发
- **模块依赖**：`tech-spec-writing` 的 approved technical spec (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-TestDesign)
- **产出契约**：向 `feature-implementation-from-spec` 交付 executable test suite (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TestDesign-FeatureImplementation)
- **复杂度**：Complex

## Module: feature-implementation-from-spec

- **持有聚合**：FeatureImplementationFromSpecSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.FeatureImplementationFromSpecSkill)
- **边界**：根据批准后的技术文档和已实现测试完成功能代码开发，不重新定义需求或技术文档语义
- **模块依赖**：`tech-spec-writing` 的 approved technical spec (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-FeatureImplementation)
- **模块依赖**：`test-design-and-implementation` 的 executable test suite (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TestDesign-FeatureImplementation)
- **产出契约**：交付 delivered change set (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.FeatureImplementation-DeliveredChange)
- **复杂度**：Complex

## Module: spec-driven-dev

- **持有聚合**：SpecDrivenDevSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.SpecDrivenDevSkill)
- **边界**：最终消费完整需求或 `ClarifiedRequirement`，调用 `modeling-first` 完成建模，在 Epic 场景生成 plan，并产出 handoff packet；本模块在其他顶级 skill 稳定后再做最终收缩与集成
- **模块依赖**：`requirements-clarification` 的 ClarifiedRequirement handoff（可选） (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.RequirementsClarification-SpecDrivenDev)
- **模块依赖**：现有 `multi-agent-loop` 的独立审查执行能力（条件依赖，用于 plan review） (upstream-ref: docs/models/process/spec-driven-dev.md#Rel.Process-MultiAgentLoop)
- **产出契约**：向 `tech-spec-writing` 交付 requirement baseline + models + optional plan + optional review notes handoff (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.SpecDrivenDev-TechSpecWriting)
- **复杂度**：Complex

---

## Dependency Graph

```text
requirements-clarification（可选入口）
  ↓
spec-driven-dev（建模 + optional plan + review）
  ├─(可选独立 plan review)→ multi-agent-loop
  ↓
tech-spec-writing
  ↓
test-design-and-implementation
  ↓
feature-implementation-from-spec

tech-spec-writing ───────────────────────────────→ feature-implementation-from-spec
```

---

## Implementation Order

1. `requirements-clarification`
2. `tech-spec-writing`
3. `test-design-and-implementation`
4. `feature-implementation-from-spec`
5. `spec-driven-dev` 最终集成 / 大改（最后做）

> 说明：上方 `Dependency Graph` 描述的是目标运行时关系；本节描述的是当前重构阶段的实际施工顺序。`spec-driven-dev` 会在其他顶级 skill 稳定后再回头做最终收缩与集成。

---

## Progress

| 模块 | 步骤 | 状态 | 备注 |
|------|------|------|------|
| requirements-clarification | 10 Implementation | done | 已新增顶级 skill，包含模板、checklist 和 golden examples |
| tech-spec-writing | 10 Implementation | done | 已新增顶级 skill，包含模板、checklist 和 golden examples |
| test-design-and-implementation | 10 Implementation | in_progress | 正在新增顶级 skill，并准备执行独立 codex 复审 |
| feature-implementation-from-spec | — | pending | 依赖 tech-spec-writing 与 test-design-and-implementation |
| spec-driven-dev | — | pending | 最终集成 / 大改留到最后，不在当前阶段提前收缩 |
