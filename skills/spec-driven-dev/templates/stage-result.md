# Stage Result（阶段结果）

**Stage**: `<clarification | modeling | plan | tech-spec | test-design-and-implementation | feature-implementation>`
`StageResult` 用于内容类 handoff 边界。Epic Plan 使用 orchestrator 产出的 StageResult，以便和 Plan Review 机械配对；Review 与 Verification 阶段的结果记录在 checkpoint / review artifact 中。
默认路径：`.spec-driven-dev/<run>/<module>/<stage-key>/stage-result.md`，并与对应 `handoff.md` 放在同一 `<stage-key>` 目录。
**Module / Scope**: `<module-name | single | _workflow>`
**Checkpoint Key**: `<module>/<stage-key>`
**Status**: `<done | blocked | failed>`
**Worker Skill Used**: `<skill-name or inline>`
**Handoff**: `<path-to-stage-handoff>`

## 产出 artifact

- `<path>: <purpose>`

## 变更文件

- `<path>: <purpose>`

## 验证执行

- `<command or check>: <pass | fail | not-run> - <short note>`

## 阶段摘要

- `<max 10 bullets; facts only>`

## 阻塞项

- `none`

## 未决问题

- `none`

## Checkpoint 增量

- `<facts the orchestrator must merge into WorkflowCheckpoint.Context Summary>`
- `<artifact index updates>`
- `next-action: start Review Decision for this content stage`
