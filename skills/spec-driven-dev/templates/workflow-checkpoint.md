# Workflow Checkpoint（流程检查点）

> **文件命名约定**（每个阶段完成后必须落盘，详见 `../SKILL.md` 的「编排契约」）：
> - **单模块**：`.spec-driven-dev/single/single/checkpoint.md`
> - **Epic 级步骤**：`.spec-driven-dev/<EpicName>/_workflow/checkpoint.md`
> - **Epic 模块步骤**：`.spec-driven-dev/<EpicName>/<ModuleName>/checkpoint.md`
> - **Epic 多 session 并行**：每个并行 session 只维护自己的模块 checkpoint，禁止多个 session 共享同一个 checkpoint 文件

**Run Mode**: `<standard | auto>`
`Run Mode` 必须填写为 `standard` 或 `auto`；检查脚本会拒绝占位符。
**Worker Execution Policy**: `<subagent-allowed | controller-only>`
`Worker Execution Policy` 在 Intake 阶段确认并写入；检查脚本会拒绝缺失或占位符。
**Review Runner Policy**: `<cross-agent-allowed | manual-only>`
`Review Runner Policy` 在 Intake 阶段确认并写入；`cross-agent-allowed` 允许 `executed:` Review Results，`manual-only` 禁止跨 agent Review runner。检查脚本会拒绝缺失或占位符。
**Scope**: `<single-module | epic>`
**Epic Parallel Strategy** (Epic only): `<serial | multi-session | N/A>`
**Current Stage**: `<intake | clarification | modeling | modeling-review | exemption-review | plan | plan-review | tech-spec | spec-review | test-design-and-implementation | test-review | feature-implementation | impl-review | verification | epic-summary>`
**Last Completed Stage**: `<same enum as Current Stage>`
**Current Module** (Epic only): `<module-name from plan.md, or N/A>`
**Status**: `<pending | in_progress | done | blocked:<reason> | partially-done>`
**Modeling Status**: `<models-ready | exemption-approved | modeling-blocked>`
**Modeling Exemption**:
- `none`
- or, when exemption is used:
- `clause: <modeling-first skip clause>`
- `clause_source: <file:line>`
- `rationale: <why this change qualifies>`
- `evidence: <files / diff size / untouched modeling areas>`
**Active Review Task**:
- `none`
- `task-name: <review-stage>-<module>`
- `runner: <opencode | claude | codex | crush>`
- `round: <1 | 2 | 3>`
- `status: <pending | running | done | error>`
**Artifact Index**:
- `<checkpoint-key>`: `<artifact path>`
**Stage Results**:
- `<checkpoint-key>`: `<stage-result path>`
**Review Results**:
- `<checkpoint-key>`: executed:.agent-loop/<task-name>/r<N>/agent-judgment.md
- `<checkpoint-key>`: skipped:<complexity + reason>（仅 `Run Mode = standard` 且符合 `guides/complexity.md`）

`<checkpoint-key>` is `<module>/<stage-key>` from `SKILL.md` Stage Registry, for example `single/modeling`, `_workflow/plan`, or `payment/tech-spec`. Use the same key as the matching Stage Results entry. Clarification is exempt from independent Review. Review task names use `<review-stage>-<module>`, for example `spec-review-single`, `plan-review-_workflow`, or `impl-review-payment`.
**Context Summary** (跨阶段累积摘要；下一会话冷启动的单一续接基线；每个阶段完成时把本阶段新增的关键信息并入此处):
- `<summary-1>`
- `<summary-2>`
**Known Blockers**:
- `none`
**Next Action**: `<start Review Decision | start Review stage | record legal Review skip | route next worker after Review Results exists | wait for user>`
**Updated**: `<ISO-timestamp>`
