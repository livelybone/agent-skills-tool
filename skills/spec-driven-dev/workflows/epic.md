# Epic 工作流

Epic 场景下，`spec-driven-dev` 先负责多单元建模和 plan（含对应 Review），再按 plan 依赖顺序把每个模块独立跑完整的 tech-spec → test → implementation 序列（每个内容阶段后面紧跟 Review 阶段）。

Review 阶段的执行机制、角色、task-name、裁决规则、runner 优先级与 `workflows/auto.md` 的「每个 Review 阶段的统一协议」完全一致。该统一协议表包含六项关键字段：`stage key / prompt / 被审查产物 / runner / task-name 规范 / 失败回退到`——**读者必须同时读本文件和 auto.md**才能得到 Epic 模式下某 Review 阶段的完整执行规则。本文件只描述 Epic 特有的**阶段组合方式**、模块维度 task-name 命名规则与 Decision Log 的模块标识补充。

## Epic 主路径

Epic 维度（只跑一次）：

```
1.  多单元建模
2.  Modeling Review（或 Exemption Review）
3.  生成 plan.md
4.  机械校验 plan（check-plan-structure.sh + check-upstream-coverage.sh）
5.  Plan Review（Epic 强制）
```

模块维度（按 plan 依赖顺序，对每个模块依次跑）：

```
6.  Tech Spec（模块 M）
7.  Spec Review（模块 M）
8.  Test Design And Implementation（模块 M）
9.  Test Review（模块 M）
10. Feature Implementation（模块 M）
11. Implementation Review（模块 M）
```

Epic 收尾（所有模块完成后跑一次）：

```
12. 汇总整个 Epic 的 workflow 状态
```

## 步骤 1 — 多单元建模

- 调用 `modeling-first` 识别所有受影响的 `docs/models/<scenario>/<name>.md`
- 先产出或更新建模单元，再进入 Modeling Review
- 不允许没有模型就直接切模块

## 步骤 2 — Modeling Review（Epic 维度）

- stage key：`modeling-review`
- prompt：`prompts/upstream-review.md`
- 被审查产物：本次产出或更新的**全部**建模单元（Epic 涉及多单元时必须一次性审查，避免单元间关系漏审）
- 触发规则：按 `guides/complexity.md` 的表格「步骤 4 Modeling Review」行（auto 模式强制；standard 模式按 complexity）
- 若走建模豁免：改用 `prompts/exemption-review.md`，按 `guides/complexity.md` 的表格「步骤 4' Modeling Exemption Review」行（任意模式任意复杂度均强制）

## 步骤 3 — Plan

Plan 回答三个问题：

1. `What`：有哪些模块
2. `Order`：模块依赖顺序如何
3. `Contract`：模块间契约是什么

Plan 不回答实现细节；实现细节属于后续 worker 阶段。

## 步骤 4 — 机械校验

Plan 生成后必须通过：

- `scripts/check-plan-structure.sh`
- `scripts/check-upstream-coverage.sh`

未通过时，不允许进入步骤 5。

## 步骤 5 — Plan Review（Epic 强制）

- stage key：`plan-review`
- prompt：`prompts/plan-review.md`
- 执行协议：同 `workflows/auto.md` 的「每个 Review 阶段的统一协议」
- Auto + Standard 两种模式下 Epic 场景**都强制执行**（Epic 的 Plan 是编排骨架，无法跳过）
- Complex Epic 建议多轮迭代（仍受 3 轮上限约束）
- 失败回退：
  - 聚合被切散 / 越界契约 / 模块边界错误 → 回到步骤 3 重写 plan
  - 发现上游建模错误 → 回到步骤 1 + 2，然后重进 plan 全链

## 步骤 6-11 — 按模块路由

对 plan 中的每个模块 M，按依赖顺序执行完整的内容 + Review 序列：

| 子步 | 阶段 | 执行规则 |
|------|------|---------|
| 6 | Tech Spec（M） | worker：`tech-spec-writing`；输入：该模块 plan 条目 + 模块涉及的建模单元 |
| 7 | Spec Review（M） | prompt：`prompts/spec-review.md`；触发规则按模块复杂度字段（见 plan）决定是否执行 |
| 8 | Test Design & Implementation（M） | worker：`test-design-and-implementation`；worker 内部另有两次自查 |
| 9 | Test Review（M） | prompt：`prompts/test-review.md`；触发规则按模块复杂度 |
| 10 | Feature Implementation（M） | worker：`feature-implementation-from-spec` |
| 11 | Implementation Review（M） | prompt：`prompts/impl-review.md`；触发规则按模块复杂度 |

模块内部**严格串行**：7 未收敛前不得进入 8；9 未收敛前不得进入 10；以此类推。

**模块之间**是否可并行，由 plan 的依赖关系决定：

- 无依赖的模块可并行启动（独立的 `WorkflowCheckpoint` + 独立的 `.agent-loop/<stage>-<module>-r1/` 工作目录）
- 有依赖的模块必须等上游模块完成步骤 11 才能启动自己的步骤 6

### Task-name 规范

Epic 场景下 Review task-name 必须带模块标识，以便多模块并行：

- `<stage>-<module>-r1` / `<stage>-<module>-r2` / `<stage>-<module>-r3`
- 例：`spec-review-payment-r1`、`impl-review-order-r2`
- **禁止**跨模块复用同一 task-name（如 `spec-review-r1`——会和其他模块冲突）

### 上下文压缩

Review 收敛后触发宿主压缩的规则在 `workflows/auto.md` 的「Review 收敛后的上下文压缩」节统一定义——"每个 Review 收敛 → Delta 合入 Summary → 压缩"。Epic 场景不新增独立触发时机；但以下两个 Epic 主路径边界恰好是该通用规则的关键应用点，值得提醒：

- **Plan Review 收敛后（步骤 5 结束）→ 进入首个模块步骤 6 前**：属于 auto.md 通用规则"Review 收敛后必须压缩"的直接落地。Epic 级信息（`plan.md` + 模块边界）必须先合入 `Context Summary`，模块内部阶段只读 Epic-level 指针
- **模块 M 步骤 11 Impl Review 收敛 → 模块 M+1 步骤 6 前**：同样是通用规则的落地。此处压缩的关键作用是确保 M 的实现细节不会污染 M+1 的 spec 构思

以上两点不是"额外触发"，**不要重复压缩**——auto.md 的通用规则已覆盖，Decision Log 按通用规则留痕即可。

#### 并行模块的压缩约束

`/compact` 是 orchestrator session 级的副作用——同一 session 内触发一次压缩会清空**所有**活跃模块的在途上下文。因此并行执行无依赖模块时，必须二选一：

- **方案 A（默认，推荐）**：同一 orchestrator session 内**串行**执行所有模块，即使 plan 允许并行。模块切换时按上方「模块切换时」规则压缩。此方案下 WorkflowCheckpoint 单文件即可，`Current Module` 字段随串行进度切换
- **方案 B**：真正并行时，**每个并行模块启动独立的 orchestrator session**（如单独的 Claude Code 会话）。每个 session 维护独立 WorkflowCheckpoint 文件，文件命名约定为 `<plan.md 所在目录>/checkpoints/<module>-checkpoint.md`，互不干扰。每个 session 按 auto.md 的压缩规则独立触发 `/compact`，不影响其他 session
- **禁止**：同一 orchestrator session 内真正并行推进多模块并做会话级压缩——会造成在途模块上下文丢失

方案选择必须在 Decision Log 的 Plan Review 决策条目中显式记录（`并行策略: serial | multi-session`）。

## 步骤 12 — Epic 汇总

完成所有模块后，orchestrator 产出 Epic 级 workflow summary：

- 每个模块分别是 `done` / `partially-done` / `blocked`
- 每个模块的 Upstream Coverage Matrix 是否通过机械校验
- 每个模块的 Review 阶段轮数与关键裁决结果
- 整个 Epic 是否可以标记 `done`（所有模块 done 且所有 Matrix 通过）、`partially-done`（部分模块完成）还是 `blocked`

## Epic 回流规则

如果后续阶段发现上游边界错误，回流顺序如下：

- 模型错了 → 回到步骤 1，修模后重进步骤 2（Modeling Review）+ 可能触发步骤 5（Plan Review）重审
- 模块边界或契约错了 → 回到步骤 3，修 plan 后重进步骤 4（机械校验）+ 步骤 5（Plan Review）
- 某模块的 tech spec 错了 → 该模块回到步骤 6 + 7
- 某模块的 tests 错了 → 该模块回到步骤 8 + 9
- 某模块的实现错了 → 该模块回到步骤 10 + 11

若 plan 被重开（步骤 3-5 重跑），所有下游模块的 handoff 视为 stale：

- 未开始的模块直接使用新 plan 重新启动
- 进行中的模块停在当前步骤，等新 plan 确认后判断是否需要回退到步骤 6

## Epic 完成条件

Epic workflow 完成时，应满足：

- 所有需要的建模单元已就绪且通过 Modeling Review（或 Exemption Review）
- `plan.md` 已通过机械校验 + Plan Review
- 每个模块都已按顺序调用对应 worker + 对应 Review
- 每个模块的 Upstream Coverage Matrix 已产出并通过 `scripts/check-upstream-coverage.sh`（多单元按 `guides/upstream-coverage.md` "Epic 多模块场景的调用方式" 分别校验）
- 每个模块的最终状态都能由 checkpoint 清晰说明
- orchestrator 能输出整个 Epic 当前是 `done`、`partially-done` 还是 `blocked`

## Auto 模式 vs Standard 模式

Epic 场景下两种模式的差异与非 Epic 场景一致：

- **Auto 模式**：步骤 2 / 5 / 7 / 9 / 11 全部强制执行，无人工 gate
- **Standard 模式**：
  - 步骤 2：分两种情形——若走正常建模，按 `guides/complexity.md`「步骤 4 Modeling Review」行判断是否执行；若走 `modeling_exemption`，**任意复杂度均强制执行** Exemption Review（不受 Epic 复杂度字段影响）
  - 步骤 5：任意复杂度均强制（Epic 的 Plan Review 是编排骨架，无法跳过）
  - 步骤 7 / 9 / 11：按 plan 中该模块的复杂度字段 + `guides/complexity.md` 对应行决定是否执行
  - 保留各 content 阶段人工 gate

## Decision Log 字段

Epic workflow 的 Decision Log 字段结构与 `workflows/auto.md` 或 `workflows/standard.md` 定义完全一致——按当前 run 的模式分别使用。Epic 特有补充：

- `当前阶段` 字段须同时写明模块标识，形如 `tech-spec:<module>` / `spec-review:<module>`
- Epic 维度阶段（步骤 1–5 + 12）写 `当前阶段` 为 `modeling` / `modeling-review` / `exemption-review` / `plan` / `plan-review` / `epic-summary`，不带模块标识
- 同一模块跨多轮 Review 时，按 `<stage>-<module>-r1/r2/r3` 记轮次到 `Review 轮次` 字段
