# Review Stage Execution Guide

本文件只补充 `SKILL.md` 中「审查契约」的执行细节，不定义新的 workflow mode 或 workflow 顺序，也不决定某个 Review 是否必须执行。

是否执行由流程本体决定：Auto 模式全部执行；Standard 模式可按 `guides/complexity.md` 合法跳过部分独立 runner；Modeling Exemption Review 与 Plan Review 始终强制。`Review Runner Policy = manual-only` 时不得启动跨 agent runner，遇到强制 Review 必须阻塞或升级。

## 统一执行协议

Review stage 通过 `multi-agent-loop` 启动独立 runner。执行机制、裁决、继续/终止、最大轮数、升级边界等 loop 协议由 `multi-agent-loop` skill 唯一定义，本文件不复述。

Review stage 不创建 `StageResult`。Controller 必须把 Review Result 登记到被审查内容阶段的 checkpoint key 上，例如 `payment/tech-spec` 的 Spec Review 写回 `WorkflowCheckpoint.Review Results` 的 `payment/tech-spec`。

| 字段 | 规定 |
|------|------|
| 角色 | **agent**（如需第二视角，另起独立 task-name） |
| Task-name 格式 | `<stage>-<module>`；`<stage>` 取自下表 review stage key；`<module>` 非 Epic 固定为 `single`，Epic 级步骤固定为 `_workflow`，Epic 模块步骤使用 plan 模块名；轮次只记录在 `r<N>/` 子目录和 checkpoint `round` 字段中 |
| Runner 默认优先级 | `opencode > claude > codex > crush`（任意 runner 不可用时按此顺序降级；降级与失败后的升级规则见 `multi-agent-loop`） |
| 修复定位 | 本阶段 worker 产物问题 → 回到对应 worker 修复；上游产物问题 → 按「失败回退到」列走上游 worker，修复后重新进入当前 Review |

| 阶段 key | 对应内容阶段 | 审查 prompt | 被审查产物 | 失败回退到 |
|----------|-------------|------------|-----------|-----------|
| `modeling-review` | 步骤 3 | `prompts/upstream-review.md` | `docs/models/<scenario>/<name>.md` | `modeling-first` |
| `exemption-review` | 步骤 3（走豁免时替代上一条） | `prompts/exemption-review.md` | `WorkflowCheckpoint.modeling_exemption` 字段 | `modeling-first`（若豁免不成立） |
| `plan-review` | 步骤 5 | `prompts/plan-review.md` | `plan.md` | 步骤 5（Plan） |
| `spec-review` | 步骤 7 | `prompts/spec-review.md` | `TechnicalSpec` | `tech-spec-writing`；若发现上游问题则 `modeling-first` / Plan |
| `test-review` | 步骤 9 | `prompts/test-review.md` | 测试场景 + 可执行测试 + Red Run 结果 | `test-design-and-implementation`；若发现 spec 语义缺口则 `tech-spec-writing` |
| `impl-review` | 步骤 11 | `prompts/impl-review.md` | `DeliveredChange` + 实现代码 | `feature-implementation-from-spec`；若发现 spec/test 语义冲突则对应上游 worker |

## 收敛后的 checkpoint 更新

Review 收敛后、进入下一 content 阶段之前，orchestrator 必须：

- 把本轮 `agent-output.md` / `agent-judgment.md` 落盘到 `.agent-loop/<task-name>/r<N>/`
- 保存本阶段修复涉及的代码/文档改动
- 把本阶段新增的关键信息并入 `WorkflowCheckpoint.Context Summary`
- 更新并落盘 `WorkflowCheckpoint` 的 `Current Stage` / `Last Completed Stage` / `Artifact Index` / `Stage Results` / `Review Results`

下一阶段恢复上下文的优先级：

1. `WorkflowCheckpoint.Context Summary`
2. `WorkflowCheckpoint.Stage Results` 中登记的上游 `StageResult`
3. 上游 worker 产出的 artifact 文件
4. 最近一轮 `agent-judgment.md`（仅在需要理解上一 Review 裁决理由时读取）

若下游阶段需要的关键信息未被 checkpoint / artifact / judgment 捕获，属于 Decision Log 质量问题：回溯到产生该信息的阶段，从文件重建上下文并补写 `Context Summary`。
