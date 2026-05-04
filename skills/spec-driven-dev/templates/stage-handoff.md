# Stage Handoff（阶段交接）

本模板只定义 orchestrator 路由给内容阶段 worker 的持久记录。Review 阶段使用 `multi-agent-loop` task 文件，不使用 `StageHandoff`。

默认路径：`.spec-driven-dev/<run>/<module>/<stage-key>/handoff.md`。`<run>` 在 Epic 场景使用 Epic name，非 Epic 固定为 `single`；`<module>` 在 Epic 模块步骤使用 plan 模块名，Epic 级步骤使用 `_workflow`，非 Epic 固定为 `single`；`<stage-key>` 使用 Stage Registry 中的 stage key。

**Handoff ID**: `<stage>-<module-or-scope>-<timestamp>`
**Stage**: `<clarification | modeling | tech-spec | test-design-and-implementation | feature-implementation>`
**Checkpoint Key**: `<module>/<stage-key>`
**Execution Mode**: `<stage-worker | inline>`
**Source Artifacts**:
- `<path-or-summary-1>`
- `<path-or-summary-2>`
`Source Artifacts` 是持久化上游文件或已批准摘要；不要在这里重复临时笔记。
**Target Worker**: `<skill-name for content stages>`
**Modeling Basis**: `<model paths | approved exemption>`
**Allowed Write Scope**:
- `<paths the worker may modify, or read-only>`
**Confirmed Inputs**:
- `<input-1>`
- `<input-2>`
`Confirmed Inputs` 是 worker 阅读 Source Artifacts 后可以依赖的具体事实。
**Required Output Artifacts**:
- `<artifact path or expected artifact description>`
- `<stage-result path; must follow templates/stage-result.md for content stages>`
**Validation Expectations**:
- `<command or manual check>`
**Blockers**:
- `none`
**Open Questions**:
- `none`
**Notes**:
- `<short routing summary; facts only — no recommended approach / trade-off matrix / leading questions for the worker>`
- `内容阶段 worker 必须作为 subagent / Task 加载 Target Worker skill，并返回 blockers；不得直接与用户交互，不得自行裁决 gate 是否推进。`
