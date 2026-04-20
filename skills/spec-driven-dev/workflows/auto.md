# Auto 模式工作流

Auto 模式是 `spec-driven-dev` 的**自动编排模式**。orchestrator 自动调用各阶段 worker，在每个阶段完成后**必须**自动发起对应的独立审查，审查通过（controller 裁决收敛）后再推进下一阶段；只有触发升级边界时才暂停给用户。

Auto 模式**不是**让 orchestrator 替代 worker 生成阶段内容。各阶段正式产物仍由对应 worker skill 生成。

## 核心语义

- `--auto` 表示自动推进模式
- 各阶段正式产物仍由对应 worker skill 生成
- **每个内容阶段后面紧跟一个强制的 Review 阶段**（见下方 13 步序列）
- Review 由 `multi-agent-loop` 启动独立 runner 执行，默认 runner 优先级：`opencode > claude > codex > crush`
- orchestrator（controller）按 `multi-agent-loop` 协议对审查结果逐条裁决，记 Decision Log
- 只有触发升级边界时才暂停给用户

## 13 步阶段序列

```
1.  Intake And Route
2.  Clarify If Needed
3.  Modeling
4.  Modeling Review               ← prompts/upstream-review.md
    (或 Modeling Exemption Review  ← prompts/exemption-review.md，走豁免时)
5.  Plan If Epic
6.  Plan Review (Epic only)       ← prompts/plan-review.md
7.  Tech Spec
8.  Spec Review                   ← prompts/spec-review.md
9.  Test Design And Implementation
10. Test Review                   ← prompts/test-review.md
11. Feature Implementation
12. Implementation Review         ← prompts/impl-review.md
13. Workflow Verification And Summary
```

非 Epic 场景跳过步骤 5 和 6，其余步骤全执行。

## 每个 Review 阶段的统一协议

Review 阶段在 auto 模式下**不可跳过**。执行机制、裁决、继续/终止、最大轮数、升级边界等 **loop 协议由 `multi-agent-loop/SKILL.md` 唯一定义**，本文件不复述。

下表只列 spec-driven-dev **特有的配置**：

| 字段 | 规定 |
|------|------|
| 角色 | **agent**（本 skill 所有 Review 阶段统一使用 agent 角色；peer 的使用交给 `multi-agent-loop` 默认规则） |
| Task-name 格式 | `<stage>-<module>-rN`，`<stage>` 取自下表的 stage key，`<module>` 在 Epic 场景带模块名（详见 `workflows/epic.md`），N 为轮次 |
| Runner 默认优先级 | `opencode > claude > codex > crush`（任意 runner 不可用时按此顺序降级；降级与失败后的升级规则见 `multi-agent-loop`） |
| 修复定位 | 本阶段 worker 产物问题 → 回到对应 worker 修复；上游产物问题 → 按「失败回退到」列走上游 worker，修复后重新进入当前 Review |

| Stage key | 对应内容阶段 | 审查 prompt | 被审查产物 | 失败回退到 |
|----------|-------------|------------|-----------|-----------|
| `modeling-review` | 步骤 3 | `prompts/upstream-review.md` | `docs/models/<scenario>/<name>.md` | `modeling-first` |
| `exemption-review` | 步骤 3（走豁免时替代上一条） | `prompts/exemption-review.md` | `WorkflowCheckpoint.modeling_exemption` 字段 | `modeling-first`（若豁免不成立） |
| `plan-review` | 步骤 5 | `prompts/plan-review.md` | `plan.md` | 步骤 5（Plan） |
| `spec-review` | 步骤 7 | `prompts/spec-review.md` | `TechnicalSpec` | `tech-spec-writing`；若发现上游问题则 `modeling-first` / Plan |
| `test-review` | 步骤 9 | `prompts/test-review.md` | Test Scenarios + Executable Tests + Red Run 结果 | `test-design-and-implementation`；若发现 spec 语义缺口则 `tech-spec-writing` |
| `impl-review` | 步骤 11 | `prompts/impl-review.md` | `DeliveredChange` + 实现代码 | `feature-implementation-from-spec`；若发现 spec/test 语义冲突则对应上游 worker |

### Review 收敛后的 Checkpoint 更新

基础规则（`SKILL.md` 核心原则 + WorkflowCheckpoint 节）：每个阶段完成后必须更新 `Context Summary` 并落盘 `WorkflowCheckpoint`。Review 收敛是 content 阶段的收敛点之一，除基础规则外还需做 Review 特有动作——

每个 Review 阶段收敛后、进入下一 content 阶段之前，orchestrator 必须：

- 把本轮 `agent-output.md` / `agent-judgment.md` 落盘（`.agent-loop/<task-name>/`）；若本轮拉起过 peer，`peer-output.md` / `peer-judgment.md` 同样落盘
- 保存本阶段修复涉及的代码/文档改动
- 执行基础规则：把本阶段新增的关键信息并入 `Context Summary`，更新并落盘 `WorkflowCheckpoint`（`Current Stage` / `Last Completed Stage` / `Context Summary`）

下一阶段的上下文恢复来源（按优先级）：

1. `WorkflowCheckpoint.Context Summary`（跨阶段累积摘要）
2. 上游 worker 产出的 artifact 文件（spec / test / model / plan / DeliveredChange 等）
3. 最近一轮 `agent-judgment.md`（以及存在时的 `peer-judgment.md`）——需要理解上一 Review 的裁决理由时读取

若下游阶段需要的关键信息未被 checkpoint / artifact / judgment 捕获（即 Context Summary 写漏了本阶段的新增），属于 Decision Log 质量问题 → 回溯到产生该信息的阶段，从文件重建上下文并补写 `Context Summary`。

## 步骤 1 — Intake And Route

- 判断需求是否需要澄清（`goal / actors / trigger / scope / acceptance signals` 是否足够）
- 判断是否为 Epic（跨多个模块、显式依赖、需要模块边界/契约）
- 确认本次为 auto 模式
- 初始化 `WorkflowCheckpoint`，记 `Run Mode: auto`
- 路由到步骤 2（需要澄清）或步骤 3（清晰）

## 步骤 2 — Clarify If Needed

- worker：`requirements-clarification`
- 输入：原始需求、已知约束、现有上下文
- 输出：`ClarifiedRequirement` 或显式 blocker
- Auto 模式下此阶段**不做**独立审查（澄清产物由下游建模 + Spec Review 链路兜底）
- 失败分流：澄清结果改变了主路径语义 → 后续阶段重新进入

## 步骤 3 — Modeling

- worker：`modeling-first`
- 输入：原始需求或 `ClarifiedRequirement`
- 输出：`docs/models/<scenario>/<name>.md`，或经批准的 `modeling_exemption`
- **路由判断**：
  - 若正常建模 → 进入步骤 4 Modeling Review
  - 若走建模豁免 → 进入步骤 4' Modeling Exemption Review（二选一，替代 Modeling Review）

## 步骤 4 — Modeling Review（强制）

- stage key：`modeling-review`
- prompt：`prompts/upstream-review.md`
- 被审查产物：本次产出或更新的全部 `docs/models/<scenario>/<name>.md`
- 继续/终止/轮数上限/裁决语义：按 `multi-agent-loop/SKILL.md` 步骤 7–9
- 失败回退：发现路径不合规 / 锚点缺失 / 虚构实体 → 回到 `modeling-first`

### 步骤 4' — Modeling Exemption Review（强制，替代步骤 4）

- stage key：`exemption-review`
- prompt：`prompts/exemption-review.md`
- 被审查产物：`WorkflowCheckpoint.modeling_exemption` 结构化字段
- 若豁免不成立 → 回到 `modeling-first`，走正常建模链（重进步骤 3 + 步骤 4）

## 步骤 5 — Plan If Epic

- 仅 Epic 执行；非 Epic 跳到步骤 7
- orchestrator 用 `templates/plan.md` 产出 `plan.md`
- 机械校验：`scripts/check-plan-structure.sh` + `scripts/check-upstream-coverage.sh`
- 两项都必须通过才能进入步骤 6

## 步骤 6 — Plan Review（Epic 强制）

- stage key：`plan-review`
- prompt：`prompts/plan-review.md`
- 被审查产物：`plan.md` + 本 Epic 涉及的所有建模单元
- 前置：机械校验已通过
- 失败回退：发现聚合被切散 / 越界契约 / 模块边界错误 → 回到步骤 5 重写 plan；发现上游建模错误 → 回到步骤 3

## 步骤 7 — Tech Spec

- worker：`tech-spec-writing`
- 输入：requirement baseline + 已通过 Review 的 models（或已通过 Exemption Review 的豁免） + optional plan + optional review notes
- 输出：`TechnicalSpec`
- Epic 场景：按 plan 依赖顺序，每个模块独立跑步骤 7 → 步骤 12（详见 `workflows/epic.md`）

## 步骤 8 — Spec Review（强制）

- stage key：`spec-review`
- prompt：`prompts/spec-review.md`
- 被审查产物：步骤 7 产出的 `TechnicalSpec`
- 失败回退：
  - 模板项缺失 / 凭空规则 / Interface 缺错误语义 → `tech-spec-writing`
  - Epic 模块边界越界 → 先校正 plan 再回到 `tech-spec-writing`
  - 应建模但未建模 → 回到 `modeling-first`，走步骤 3 + 4 + 重进步骤 7 + 8

## 步骤 9 — Test Design And Implementation

- worker：`test-design-and-implementation`
- 输入：已通过 Spec Review 的 `TechnicalSpec`
- 输出：Test Scenarios + Executable Test Suite + Red Run 结果
- worker 内部已有 `scenario-review.md` / `test-review.md` 两次自查（见 worker SKILL step 3 / step 7）；orchestrator 不替代这两次内部自查，但步骤 10 会在 handoff 边界做独立第二视角审查

## 步骤 10 — Test Review（强制）

- stage key：`test-review`
- prompt：`prompts/test-review.md`
- 被审查产物：Test Scenarios + Executable Tests + Red Run 结果（作为整体 handoff 审查）
- 失败回退：
  - 场景测试断链 / 追溯断链 / 覆盖不足 → `test-design-and-implementation`
  - Red Run 异常 → `test-design-and-implementation`（检查 stub 或断言）
  - 发现 spec 语义缺口 → `tech-spec-writing`，重进步骤 7 + 8 + 9 + 10

## 步骤 11 — Feature Implementation

- worker：`feature-implementation-from-spec`
- 输入：已通过 Test Review 的 `TechnicalSpec` + `ExecutableTestSuite` + 相关 models
- 输出：`DeliveredChange` + 生产代码

## 步骤 12 — Implementation Review（强制）

- stage key：`impl-review`
- prompt：`prompts/impl-review.md`
- 被审查产物：`DeliveredChange` + `Changed Files` 中的实际代码 + 验证命令结果
- 失败回退：
  - 假交付 / stub 残留 / 硬编码作弊 / 验证未通过 → `feature-implementation-from-spec`
  - 擅改测试 / 擅改 spec/model → 拒绝本次交付，回退到对应上游 worker
  - 发现 spec 语义缺口 → `tech-spec-writing`
  - 发现测试设计缺口 → `test-design-and-implementation`

## 步骤 13 — Workflow Verification And Summary

由 orchestrator 执行：

1. 运行 `scripts/check-upstream-coverage.sh` 对最终 Upstream Coverage Matrix 做机械校验（多模块场景按 `guides/upstream-coverage.md` "Epic 多模块场景的调用方式" 分别执行）
2. 汇总 workflow summary：
   - 本次经过了哪些阶段
   - 每个 Review 阶段的轮数、关键裁决、最终结论
   - 最终交付物（`DeliveredChange` 或显式 blocker）
   - Upstream Coverage Matrix 是否通过
   - 残留 `Residual Risks` / `Unfinished Items`
   - 下一次会话如何从 `WorkflowCheckpoint` 续接

失败分流规则（同 `workflows/standard.md` 步骤 13）：

- Matrix exit 2 → 对应阶段 worker 修复虚假 upstream-ref
- Matrix exit 3 → `feature-implementation-from-spec` 补覆盖行或 NOT APPLICABLE 理由
- Matrix exit 4 → 按位置失真所在列回到对应 worker
- Matrix exit 5 → orchestrator 修复 matrix 文件本身

## Auto 模式下 orchestrator 的职责

### 1. 自动路由 worker 与 Review

- 各内容阶段自动调用对应 worker
- 每个内容阶段完成后**自动**发起对应 Review 阶段（不等用户触发）
- Review 收敛（无真 Major 发现）后才推进下一阶段

### 2. 维护编排级记录

- **Decision Log**：每个 stage（包括 Review 阶段的每一轮）都要记录一条，字段见下方「Decision Log 字段」
- **WorkflowCheckpoint**：每个 stage 完成后立即更新 `Current Stage` / `Last Completed Stage` / `Status`
- **workflow summary**：步骤 13 面向用户的汇总

### 3. 裁决 Review 结果

执行 `multi-agent-loop/SKILL.md` 步骤 7–9 的通用规则。本 skill 特有的补充仅两条：

- 每一轮 Review 的结果都要单独写入 Decision Log 一条记录（字段见下方「Decision Log 字段」）
- 若 controller 判断 Review 发现涉及**上游阶段产物**（如在 Spec Review 里发现 plan 有问题），回退按「每个 Review 阶段的统一协议」下方 stage 表中的"失败回退到"列执行，不就地修复

## 禁止行为

- 不得因为 `--auto` 就跳过 Review 阶段
- 不得跳过 `agent-judgment.md` 裁决文件（multi-agent-loop 的 judgment gate 会直接拒绝下一轮）
- 不得把 worker 模板直接复制回 orchestrator 中维护
- 不得在未生成阶段正式产物时伪造"已完成"状态
- 不得以"上下文太长"为由暂停普通流程；应先完成 Review 收敛并落盘 checkpoint，再把压缩时机交还给宿主 harness

## 升级边界

以下情况必须停止自动推进并升级给用户：

- 需求语义本身存在冲突
- 建模或 plan 需要超出当前权限的边界调整
- worker 返回的 blocker 会改变后续阶段的核心行为
- Review 出现无法自主裁决的结论冲突（涉及产品、架构、安全、重大权衡）
- Review 触发 `multi-agent-loop` 的循环上限且仍未收敛（上限值由 `multi-agent-loop` 定义）
- 所有 runner 都不可用（runner 降级规则见 `multi-agent-loop/SKILL.md`，本 skill 仅在「每个 Review 阶段的统一协议」表中规定默认优先级 `opencode > claude > codex > crush`）
- 用户明确保留了需要人工确认的 gate

## Auto 模式完成条件

Auto run 完成时，用户应能看到：

- 本次 workflow 经过了哪些阶段（13 步序列中哪些实际执行、哪些跳过）
- 每个 Review 阶段的轮数与最终裁决结果
- 最终交付物（`DeliveredChange` 或显式 blocker）
- Upstream Coverage Matrix（已通过 `scripts/check-upstream-coverage.sh`）
- 残留 `Residual Risks` / `Unfinished Items`
- 所有升级边界触发点与对应的用户裁决结论

## Decision Log 字段

```markdown
### [阶段] 决策 #N

- 模式：auto
- 当前阶段：<stage key，如 tech-spec / spec-review>
- 阶段类型：content | review
- 调用 worker / runner：<skill 或 runner 名>
- Review 轮次：<r1 / r2 / r3 或 N/A>
- 输入摘要：<关键输入>
- 结果：<完成 / 回退 / blocked / escalated>
- 关键 findings（Review 阶段）：<controller 裁决后的真 Critical/Major 条目摘要>
- Context Summary 新增：<本阶段并入 `Context Summary` 的关键信息；若本阶段无新增，写 `无`>
- 原因：<为什么>
- 后续动作：<next stage / retry / escalation>
```

**编码约定**：`Context Summary` 是跨阶段累积的单一续接基线，供下一会话冷启动使用；每个阶段完成时必须把本阶段新增并入 `Context Summary`，并在 Decision Log 的「Context Summary 新增」字段留副本
