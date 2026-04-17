# Workflow Checkpoint

> **文件命名约定**（压缩启用时必须落盘，详见 `../SKILL.md` 的 Checkpoint And Handoff 节）：
> - **单模块**：推荐 `.spec-driven-dev/workflow-checkpoint.md`（仓库根下隐藏目录，单文件）；若使用者另有偏好可自选但需在首次 Decision Log 中记录路径
> - **Epic 串行**（`workflows/epic.md` 方案 A）：推荐 `<plan.md 所在目录>/checkpoint.md`
> - **Epic 多 session 并行**（`workflows/epic.md` 方案 B）：每模块一个文件，**必须**命名为 `<plan.md 所在目录>/checkpoints/<module>-checkpoint.md`

**Run Mode**: `<standard | auto>`
**Scope**: `<single-module | epic>`
**Epic Parallel Strategy** (Epic only): `<serial | multi-session | N/A>`
**Current Stage**: `<intake | clarification | modeling | modeling-review | exemption-review | plan | plan-review | tech-spec | spec-review | test-design-and-implementation | test-review | feature-implementation | impl-review | verification | epic-summary>`
**Last Completed Stage**: `<same enum as Current Stage>`
**Current Module** (Epic only): `<module-name from plan.md, or N/A>`
**Status**: `<pending | in_progress | done | blocked:<reason> | partially-done>`
**Modeling Status**: `<models-ready | exemption-approved | modeling-blocked>`
**Modeling Exemption**:
- `none`
- `clause: <modeling-first skip clause>`
- `clause_source: <file:line>`
- `rationale: <why this change qualifies>`
- `evidence: <files / diff size / untouched modeling areas>`
**Active Review Task**:
- `none`
- `task-name: <stage>-<module>-rN`
- `runner: <opencode | claude | codex | crush>`
- `round: <1 | 2 | 3>`
- `status: <pending | running | done | error>`
**Context Summary** (跨阶段累积摘要；压缩后下一阶段的主要恢复基线；Delta 在每次压缩前合入此处):
- `<summary-1>`
- `<summary-2>`
**Context Summary Delta** (仅当前阶段新增、尚未合入 Summary 的隐性信息；压缩前必须合入 Summary 并清空此字段):
- `<delta-1-or-empty>`
**Last Compaction**:
- `stage: <stage key where compact was triggered>`
- `harness: <claude-code | codex | opencode | other:<name>>`
- `status: <compacted | unsupported | skipped:<reason>>`
- `at: <ISO-timestamp>`
**Known Blockers**:
- `none`
**Next Action**: `<route next worker, start next Review stage, or wait for user>`
**Updated**: `<ISO-timestamp>`
