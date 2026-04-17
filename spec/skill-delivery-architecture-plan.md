# Plan — skill-delivery-architecture

**Context**: 将当前偏胖的 `spec-driven-dev` 重构为“顶层流程编排器”，并拆出澄清、技术文档、测试、实现四个顶级 worker skill
**Source**: 当前对话中用户确认的目标边界：`spec-driven-dev` 保留完整流程入口与 `--auto` 自动推进语义，但不再深度维护各阶段的详细内容模板；clarification/spec/test/impl 细节下放到独立顶级 worker skill
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
- **产出契约**：向 `test-design-and-implementation` 交付 approved technical spec（使用稳定章节名，供下游 `spec-ref` 追溯） (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-TestDesign)
- **产出契约**：向 `feature-implementation-from-spec` 交付 approved technical spec（使用稳定章节名，供下游 `spec-ref` 追溯） (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-FeatureImplementation)
- **复杂度**：Medium

## Module: test-design-and-implementation

- **持有聚合**：TestDesignAndImplementationSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.TestDesignAndImplementationSkill)
- **边界**：根据技术文档生成测试场景并实现测试，不承担功能代码开发
- **模块依赖**：`tech-spec-writing` 的 approved technical spec (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-TestDesign)
- **产出契约**：向 `feature-implementation-from-spec` 交付 executable test suite（含 Scenario ID 与 `@scenario` / `@spec-ref` 最小追溯） (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TestDesign-FeatureImplementation)
- **复杂度**：Complex

## Module: feature-implementation-from-spec

- **持有聚合**：FeatureImplementationFromSpecSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.FeatureImplementationFromSpecSkill)
- **边界**：根据批准后的技术文档和已实现测试完成功能代码开发；若存在上游模型约束，必须按模型追溯实现，不重新定义需求或技术文档语义
- **模块依赖**：`tech-spec-writing` 的 approved technical spec (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TechSpecWriting-FeatureImplementation)
- **模块依赖**：`test-design-and-implementation` 的 executable test suite (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.TestDesign-FeatureImplementation)
- **模块依赖**：相关 `docs/models/<scenario>/<name>.md`（若上游存在，用于实现追溯与 upstream coverage） (upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.ModelingBundle)
- **产出契约**：交付 traceable `DeliveredChange`（包含 `Spec Completeness Matrix`、`Upstream Coverage Matrix`、`Validation`、`Blockers`、`Unfinished Items`、`Residual Risks` 和 `Status`） (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.FeatureImplementation-DeliveredChange)
- **复杂度**：Complex

## Module: spec-driven-dev

- **持有聚合**：SpecDrivenDevSkill Aggregate (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Aggregate.SpecDrivenDevSkill)
- **边界**：作为规范驱动开发的顶层流程编排器，保留完整流程入口与阶段 gate；负责在 clarification、modeling、plan、tech spec、test design、feature implementation、verification 之间路由与回退，但不再深度维护各阶段内容模板
- **模块依赖**：`requirements-clarification` 的 ClarifiedRequirement handoff（可选） (upstream-ref: docs/models/domain/skill-delivery-architecture.md#Rel.RequirementsClarification-SpecDrivenDev)
- **模块依赖**：`modeling-first` 的建模执行能力（必选） (upstream-ref: docs/models/process/spec-driven-dev.md#Rel.Process-ModelingFirst)
- **模块依赖**：现有 `multi-agent-loop` 的独立审查执行能力（条件依赖，用于 plan review） (upstream-ref: docs/models/process/spec-driven-dev.md#Rel.Process-MultiAgentLoop)
- **模块依赖**：`tech-spec-writing` 的技术文档执行能力（必选阶段） (upstream-ref: docs/models/process/spec-driven-dev.md#Rel.Process-TechSpecWriting)
- **模块依赖**：`test-design-and-implementation` 的测试设计与实现能力（必选阶段） (upstream-ref: docs/models/process/spec-driven-dev.md#Rel.Process-TestDesignAndImplementation)
- **模块依赖**：`feature-implementation-from-spec` 的实现与交付能力（必选阶段） (upstream-ref: docs/models/process/spec-driven-dev.md#Rel.Process-FeatureImplementation)
- **产出契约**：向各阶段 worker 交付 stage handoff contract（在流程层封装当前已确认的输入边界和上游产物） (upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.StageHandoff)
- **产出契约**：向 controller / 新会话暴露 WorkflowCheckpoint，用于断点续接、阶段 gate 和 `--auto` 自动推进 (upstream-ref: docs/models/domain/spec-driven-dev.md#Entity.WorkflowCheckpoint)
- **复杂度**：Complex

---

## Dependency Graph

```text
spec-driven-dev（顶层流程编排入口，支持 --auto）
  ├─(需求模糊时)→ requirements-clarification
  ├─(始终)→ modeling-first
  ├─(Epic 时)→ plan
  ├─(按需独立审查)→ multi-agent-loop
  ├─→ tech-spec-writing
  ├─→ test-design-and-implementation
  └─→ feature-implementation-from-spec

tech-spec-writing ───────────────────────────────→ test-design-and-implementation
tech-spec-writing ───────────────────────────────→ feature-implementation-from-spec
test-design-and-implementation ──────────────────→ feature-implementation-from-spec
```

---

## Implementation Order

1. `requirements-clarification`
2. `tech-spec-writing`
3. `test-design-and-implementation`
4. `feature-implementation-from-spec`
5. `spec-driven-dev` 最终集成 / 大改（最后做）

> 说明：上方 `Dependency Graph` 描述的是目标运行时关系；本节描述的是当前重构阶段的实际施工顺序。`spec-driven-dev` 会在其他顶级 worker skill 稳定后回头做最终集成，从 all-in-one 执行 skill 收缩为流程编排器。

---

## Progress

| 模块 | 步骤 | 状态 | 备注 |
|------|------|------|------|
| requirements-clarification | 10 Implementation | done | 已新增顶级 skill，包含模板、checklist 和 golden examples |
| tech-spec-writing | 10 Implementation | done | 已新增顶级 skill，包含模板、checklist 和 golden examples |
| test-design-and-implementation | 10 Implementation | done | 已新增顶级 skill，包含模板、checklist 和 golden examples |
| feature-implementation-from-spec | 10 Implementation | done | 已新增顶级 skill，包含模板、checklist 和 golden examples |
| spec-driven-dev | — | pending | 最终集成 / 大改留到最后，目标是保留总入口并改成流程编排器 |
