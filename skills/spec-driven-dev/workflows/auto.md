# Auto 模式工作流

Auto 模式是 `spec-driven-dev` 的自动编排模式。通用阶段顺序、stage key、role、artifact 路径、StageResult / ReviewResults 配对规则由 `SKILL.md` 的 Stage Registry 和「编排契约」定义；本文件只记录 Auto 模式差异、自动推进规则和升级边界。

## 核心语义

- `--auto` 表示自动推进模式，不等待普通人工 gate。
- Auto 模式固定采用 `Review Skip Policy = never`；即使 checkpoint 写了其它值，也不得跳过 Review。
- 非 Epic 场景跳过 `plan` / `plan-review`，其余阶段按 Stage Registry 执行。
- Epic 场景按 `workflows/epic.md` 在模块维度重复步骤 7-12。
- 每个内容阶段后面紧跟强制 Review 阶段；Auto 模式下 Review Decision 只能是 `executed`。
- `WorkflowCheckpoint.Review Results` 缺项时不得推进到下一内容阶段。
- 只有触发升级边界时才暂停给用户。

## 自动执行 Overlay

| 阶段 | Auto 差异 |
|------|-----------|
| `clarification` | Controller 直接向用户提出必要问题；subagent 不直接与用户交互。澄清阶段不做独立 Review |
| `modeling` | `StageResult.Status = done` 后必须进入 `modeling-review` 或 `exemption-review` |
| `plan` | 仅 Epic 执行；产出 `StageResult` 并以 `_workflow/plan` key 写入 checkpoint；必须通过 plan / upstream 机械校验 |
| `tech-spec` | 自动委派 `tech-spec-writing` Stage Worker，完成后进入 `spec-review` |
| `test-design-and-implementation` | 自动委派 `test-design-and-implementation` Stage Worker，`StageResult` 必须登记场景、测试文件和 Red Run 状态 |
| `feature-implementation` | 自动委派 `feature-implementation-from-spec` Stage Worker，`StageResult` 必须登记 changed files、验证命令和交付状态 |
| Review stages | 全部按 `guides/review.md` 启动 `multi-agent-loop` runner，不允许 complexity skip |

若 Medium / Complex 内容阶段没有可用 subagent / Stage Worker，Auto 模式必须停为 blocker 并升级；不得把它降级为 Controller inline 内容生产。

## Controller 职责

- 每个内容阶段先生成 `StageHandoff`，再启动 Stage Worker，最后读取 `StageResult` 判断是否进入 Review。
- 每个 Review 阶段收敛后必须更新 `WorkflowCheckpoint.Review Results`；缺失时停止推进并补写。
- 每个 stage（包括 Review 阶段的每一轮）都要写 Decision Log。
- 每个 stage 完成后立即更新 `WorkflowCheckpoint.Current Stage` / `Last Completed Stage` / `Status` / `Artifact Index` / `Stage Results` / `Review Results`。
- Review 发现涉及上游阶段产物时，回退按 `guides/review.md` 的「失败回退到」列执行，不就地修复。

## Workflow Verification

由 Controller 执行：

1. 运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh` 对最终 Upstream Coverage Matrix 做机械校验。
2. 运行 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-review-results.sh --checkpoint <path>`，确认每个内容 stage（Clarification 除外）都有对应 `Review Results`。
3. 输出 workflow summary：阶段清单、Review 轮数与关键裁决、最终交付物、Upstream Coverage Matrix 状态、残留风险和 checkpoint 续接方式。

失败分流规则同 `workflows/standard.md` 的 Workflow Verification。

## 禁止行为

- 不得因为 `--auto` 跳过 Review 阶段。
- 不得把 Review runner 不可用、缺少授权或执行失败改写为 `skipped`；必须停为 blocker 或升级给用户。
- 不得因为 `--auto` 让 Controller 吞掉内容阶段；内容阶段仍需 handoff + artifact + stage result。
- 不得跳过 `agent-judgment.md` 裁决文件。
- 不得把 worker 模板直接复制回 Controller 中维护。
- 不得在未生成阶段正式产物时伪造「已完成」状态。
- 不得以「上下文太长」为由暂停普通流程；应先完成 Review 收敛并落盘 checkpoint。

## 升级边界

以下情况必须停止自动推进并升级给用户：

- 需求语义本身存在冲突。
- 建模或 plan 需要超出当前权限的边界调整。
- worker 返回的 blocker 会改变后续阶段的核心行为。
- Review 出现无法自主裁决的产品、架构、安全或重大权衡冲突。
- Review 触发 `multi-agent-loop` 的循环上限且仍未收敛。
- 所有 runner 都不可用。
- 用户明确保留了需要人工确认的 gate。

## Auto 模式完成补充

完成条件以 `SKILL.md` 的「完成定义」为准。Auto 模式的 workflow summary 额外列出所有自动执行的 Review 轮数、关键裁决，以及所有升级边界触发点与用户裁决结论。
