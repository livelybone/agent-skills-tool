# Auto 模式详细规则

> **前置依赖**：Auto 模式保留标准模式的所有执行步骤（Stub、Red Run、Baseline、Spec 完整性校验、CI 最低检查等）。执行具体步骤时，**必须同时参考 `workflows/standard.md` 中对应步骤的细则**。本文件只补充 Auto 模式特有的裁决规则和报告格式。跨 agent 审查机制见 SKILL.md > 跨 Agent 审查原则。

## 概述

Auto 模式是一种全自动执行模式，**不管需求复杂度**，强制流程全部自动化。AI 承担所有审查和裁决职责，人工不介入中间环节。流程结束后，输出完整的 **Decision Report**。

## 与标准模式的区别

| 环节               | 标准模式                        | Auto 模式                               |
| ------------------ | ------------------------------- | --------------------------------------- |
| 建模（步骤 0）      | 人工审查建模产物                | **强制** AI 跨 agent 审查 + AI 自主裁决 |
| Spec Review        | 按复杂度可选 AI 审查 + 人工审查 | **强制** AI 跨 agent 审查 + AI 自主裁决 |
| Scenario Review    | 按复杂度可选 AI 审查 + 人工审查 | **强制** AI 跨 agent 审查 + AI 自主裁决 |
| Test Review        | 按复杂度可选 AI 审查 + 人工审查 | **强制** AI 跨 agent 审查 + AI 自主裁决 |
| Red Run            | 始终执行                        | 始终执行                                |
| Plan Review (Epic) | 人工确认                        | AI 自主裁决                             |
| 中间暂停点         | 每个 Human Review 步骤暂停      | **不暂停**，全程自动推进                |
| Decision Log       | 无                              | **强制维护**                            |
| 流程结束           | 无汇总                          | 输出完整 **Decision Report**            |

## 触发方式

两种触发方式：

**1. 从头启动**：在需求描述中指定 `--auto`

```
/spec 实现订单退款流程 --auto
```

**2. 中途切换**：标准模式执行中随时指定 `--auto`

```
Spec 我已经审查通过了，后面 --auto 帮我走完
```

中途切换时：

- 已完成的人工步骤保留，不重新审查
- 从下一个未完成步骤开始按 Auto 规则执行（包括禁止中断、禁止简化审查等全部约束）
- **部分完成的步骤**：产物已生成但未审查 → 从该步骤的审查环节开始；步骤进行到一半 → 从该步骤的开头重新执行
- Decision Log 从切换点开始记录
- Decision Report 开头标注切换点和人工已完成的步骤清单

---

## 禁止中断规则

**Auto 模式下，除裁决升级条件（见下方）外，AI 不得以任何理由暂停流程等待用户确认。**

以下均**不是**合法的暂停理由：

- "上下文变长了"（→ 应触发 context 压力处理：写检查点 → 压缩 → 继续，见 SKILL.md > Context 压力处理）
- "先确认一下再继续"
- "这一步比较复杂，暂停一下"
- "阶段性汇报进度"
- "修复完成，等待指示"
- 任何形式的"要继续吗？"

遇到这些情况时，正确做法是**继续执行下一步**，将中间状态记录到 Decision Log。Context 接近上限时，正确做法是写检查点 → 压缩上下文 → 继续执行（不是暂停）。

唯一允许中断的情况是触发了裁决升级条件（见下方"裁决升级"章节）。中断时必须明确说明触发了哪一条升级条件。

## 禁止简化审查规则

**Auto 模式下，所有跨 agent 审查步骤均为强制执行，不得降级、简化或跳过。**

以下均**不是**简化审查的合法理由：

- "改动范围小 / 改动简单"
- "上下文太长了"（→ 应触发 context 压力处理，不是简化审查的理由）
- "与前一个模块类似"
- "是增量补齐，不是新功能"
- "subagent 已经完成了完整流程"（subagent 执行 ≠ 跨 agent 审查）
- "已经经过 N 轮审查了"
- **"无可用异构 agent"**（`multi-agent-loop` 支持用同一 agent 启动独立进程，见 SKILL.md > 跨 Agent 审查原则。这个理由永远不成立）

**每个模块的每个审查步骤必须独立、完整地执行跨 agent 审查**——即使该模块看起来很简单、改动很小、或与其他模块高度相似。

### 客观技术故障的处理（非降级豁免）

上述"禁止简化"规则针对的是**主观判断导致的跳过或降级**。若因客观技术故障（agent CLI 崩溃、API 持续超时、网络不可达）导致跨 agent 审查**无法执行**，按以下流程处理：

1. **必须先重试**：至少重试 1 次（含切换可用 runner），确认确实不可恢复
2. **升级给用户裁决**：报告故障原因，由用户决定：等待恢复后继续 / 接受降级继续
3. **用户选择接受降级时**：在 Decision Log 中记录为 `[审查降级-用户授权]`，注明故障原因和用户授权时间；在 Decision Report 的"流程完整性"中标记为 ⚠️；在"建议用户复核的内容"中列出未审查的模块和步骤

**关键区分**：AI 不得自主决定降级——"CLI 不可用"是升级条件，不是自主降级的理由。

---

## 禁止并行审查规则

**单个模块内的流程步骤（0→1→…→13）必须严格顺序执行，不得并行。**

原因：每个审查步骤可能触发迭代修正（见 `guides/iteration-rules.md`），后续步骤的输入依赖前置步骤的审查结果：

- Spec 审查可能修改 Spec → Scenario 需要重新生成
- Scenario 审查可能补充/修改 Scenario → Test 需要重新实现
- Test 审查可能发现翻译偏差 → Test 需要修复后才能 Red Run

并行审查等于假设"前面的审查不会发现任何问题"——这与审查的存在意义矛盾。

**允许并行的唯一场景**：Epic 中**不同模块之间**可以并行（前提是模块间无依赖关系）。同一模块内的步骤永远串行。

---

## Subagent 使用边界

Subagent（如 `subagent-driven-development`）是执行工具，不是流程替代品。

### Subagent 可以做的

- 执行单个步骤的具体任务（如：根据已审查的 Scenario 编写测试代码、根据已审查的 Spec 实现功能）
- 并行执行多个模块中**同一步骤**的实现工作

### Subagent 不可以做的

- **不得将多个流程步骤打包成一个 subagent 任务**（如"写 Spec + 生成 Scenario + 写测试 + 实现功能"）
- **不得替代跨 agent 审查**——subagent 执行完成后，controller 仍必须启动跨 agent 审查
- **不得跳过阶段性产物生成**——subagent 的输出必须是当前步骤的产物，不是最终代码

### 违规模式识别

以下用法等于绕过流程，必须避免：

- 将"按照 spec-driven-dev 流程实现 XX 模块"作为 subagent 的 prompt → 这把整个流程塞进了一个黑盒
- 对后续模块"参照 RT-1 的模式直接实现" → 每个模块必须独立走完流程
- 用 subagent 输出直接替代 Scenario 文件 → Scenario 必须作为独立的 `.scenarios.md` 产物存在

---

## 阶段性产物检查点

Auto 模式下，每个模块在推进到下一步之前，**必须产出对应的阶段性产物**。Controller 在推进前检查产物是否存在。

| 步骤                   | 必须产出                           | 产物位置           |
| ---------------------- | ---------------------------------- | ------------------ |
| 建模（步骤 0）          | `model.md` 或增量更新记录           | `<module>/` 或 DoR 豁免记录 |
| 跨 agent 审查建模       | Decision Log 条目                  | `$TMPDIR` 临时文件或当前会话 |
| Spec 生成              | `<module>.md`                      | `spec/`            |
| 跨 agent 审查 Spec     | Decision Log 条目                  | `$TMPDIR` 临时文件或当前会话（受下方"存放位置"条款约束）           |
| Scenario 生成          | `<module>.scenarios.md`            | `spec/`            |
| 跨 agent 审查 Scenario | Decision Log 条目                  | `$TMPDIR` 临时文件或当前会话（受下方"存放位置"条款约束）           |
| Test Implementation    | 测试文件（按 `guides/repo-structure.md` 规则） | `src/` 或 `tests/` |
| 跨 agent 审查 Test     | Decision Log 条目                  | `$TMPDIR` 临时文件或当前会话（受下方"存放位置"条款约束）           |
| Red Run                | 运行结果记录（全部红色）           | 当前会话           |
| Feature Implementation | 实现代码                           | `src/`             |
| Spec 完整性校验        | 完整性矩阵                         | 当前会话           |
| CI Verification        | CI 通过记录                        | 当前会话           |

**缺少任何一项产物即视为该步骤未完成，禁止推进到下一步。**

**进度检查点更新**：每个步骤完成后，**必须立即更新**对应文件的检查点（`spec/<module>.md` frontmatter 或 `plan.md` Progress 表）。这与产物产出同等重要——检查点是跨会话续接的唯一依据。详见 SKILL.md > 进度检查点。

### Decision Log / Decision Report 的存放位置（硬性约束）

**Decision Log 和 Decision Report 是会话产物，禁止落盘到仓库。**

允许的存放方式（按优先级）：

1. ✅ **`$TMPDIR` 临时文件**（推荐）：写入 `$TMPDIR/spec-driven-dev-<session-id>/decision-log.md`（会话结束或系统重启自动清理）。优势：不受 context 压缩影响，大型 Epic Auto 模式下不会丢失
2. ✅ **会话上下文中维护**：对于短流程（单模块、低复杂度）可直接在会话中维护
3. ✅ **两者并用**：在 `$TMPDIR` 维护完整版，同时在会话中维护摘要版

- ❌ 禁止：写入仓库内任何路径，包括但不限于：
  - `spec/<epic>.decision-log.md`
  - `spec/<module>.decision-log.md`
  - `spec/<epic>.decision-report.md`
  - `docs/`、`memory/` 下的等价文件

理由：

1. Decision Log 是流程内部状态，不是交付物；Decision Report 的消费者是当前会话的用户，不是未来的读者
2. 落盘到仓库会产生维护负担（PR review、版本化、清理）且与"会话产物"定位矛盾
3. `$TMPDIR` 临时文件解决了 context 压缩导致 Decision Log 丢失的问题，同时避免了仓库污染
4. 如需跨会话追溯，走 git log / PR 描述，不走 spec/ 目录

**`$TMPDIR` 使用规范**：
- 目录结构：`$TMPDIR/spec-driven-dev-<session-id>/`（session-id 可用时间戳或 PID）
  - Decision Log：`decision-log.md`（流程中持续追加）
  - Decision Report：`decision-report.md`（流程结束时生成）
- 流程结束后将 `$TMPDIR` 中的 Decision Report 输出到会话给用户
- 不主动清理——依赖 OS 的 `$TMPDIR` 自动清理机制
- **禁止将 `$TMPDIR` 路径提交到 git 或写入任何持久化配置**

**例外**：仅当仓库级 CLAUDE.md **同时满足以下全部条件**时，方可落盘到仓库：

1. 在 CLAUDE.md 中**按名字显式点到** "Decision Log" 和/或 "Decision Report"（不接受"中间产物"、"过程记录"、"审查记录"等泛化表述的推定豁免）
2. 明确指定落盘路径（如 `spec/<epic>.decision-log.md`）
3. 明确说明保留策略（何时清理、是否纳入 PR review）

skill 本身不产生仓库落盘行为。任何未同时满足上述三项的仓库级表述，一律按"禁止仓库落盘"处理。

**豁免粒度**：豁免只对 CLAUDE.md 中**按名字被点到**的那一类产物生效——只点到 "Decision Log" 不意味着 "Decision Report" 也被豁免，反之亦然。

### Epic 模块间一致性

Epic 包含多个模块时，**后续模块必须与前置模块保持相同的流程严格度**。已知退化模式：

- 前 1-2 个模块流程规范，后续模块逐步简化 → 禁止
- 前置模块走完整审查，后续模块"参照前面的"跳过 → 禁止
- 上下文变长后用 subagent 一把梭 → 禁止

每个模块都是独立的 spec-driven-dev 流程实例，不继承前置模块的审查结论。
同一模块的跨 agent 审查若进入下一轮，必须创建新的 `task-name` 和目录，例如 `spec-review-orders-r1` → `spec-review-orders-r2`；禁止复用同一目录覆盖前一轮产物。

---

## AI 裁决规则

### 裁决权限

AI **可以自主裁决**的：

- Spec 中的歧义或遗漏（AI 直接补充，记录裁决）
- Scenario 的覆盖度不足（AI 直接补充场景，记录裁决）
- Test 与 Scenario 的翻译偏差（AI 直接修复，记录裁决）
- Plan 中的模块边界和依赖关系调整

### 裁决原则

1. **保守优先**：有歧义时选择更安全、更受限的解释
2. **完整性优先**：宁多不少——多一个边界场景比少一个更安全
3. **一致性优先**：裁决必须与 Spec 已有规则一致，不得引入矛盾
4. **可追溯**：每个裁决必须记录原因和替代方案

### 裁决升级（Auto 模式的中断点）

以下情况 AI **必须中断流程并报告用户**，不允许自主裁决：

- **需求本身存在根本性矛盾**（如两条规则互相冲突且无法通过优先级解决）
- **安全风险**（如发现需求隐含的安全漏洞）
- **超出 Spec 边界的架构决策**（如需要引入新的外部依赖或改变系统架构）
- **需求信息不足**（DoR 校验不通过——功能目标不清晰、业务规则缺失、范围不明确、依赖未知）
- **功能无法实现**（Spec 完整性校验发现某功能域因客观原因无法实现）
- **CI 持续失败**（修复尝试超过 2 轮仍无法通过 CI）

---

## Decision Log 格式

> ⚠️ **存放位置**：维护在 `$TMPDIR` 临时文件或当前会话中，禁止落盘到仓库。详见上文"Decision Log / Decision Report 的存放位置（硬性约束）"。

Auto 模式全程维护一个结构化的 Decision Log，每条记录包含：

```markdown
### [阶段] 裁决 #N

- **模块**：[模块名称，单模块任务写"—"]
- **发现**：[描述发现的问题]
- **受影响条目**：[具体的 Spec 规则 / Scenario 编号 / 测试文件:行号 / Plan 模块名]
- **变更前**：[原文或原状态，简要引用]
- **裁决（变更后）**：[采取的行动及变更后的内容]
- **理由**：[为什么这样裁决]
- **替代方案**：[考虑过但未采用的方案]
- **风险等级**：Low / Medium / High
- **影响范围**：[哪些后续步骤受影响]
```

### 风险等级判定标准

- **High**：改变了业务规则语义、影响多个下游步骤、或涉及金钱/权限/数据完整性
- **Medium**：补充了遗漏的边界场景、调整了测试断言、或修正了 Spec 歧义
- **Low**：格式/术语修正、覆盖度微调、无语义影响的补充

### 阶段标签

`[Modeling Review]`、`[Plan Review]`、`[Spec Review]`、`[Scenario Review]`、`[Test Review]`、`[CI Verification]`

---

## Decision Report 格式

> ⚠️ **存放位置**：维护在 `$TMPDIR` 临时文件或当前会话中，流程结束后输出给用户。禁止落盘到仓库。详见上文"Decision Log / Decision Report 的存放位置（硬性约束）"。

流程结束后，输出 Decision Report。**完整性语义**：Report 基于生成时可获取的状态判定——若 Decision Log 已被 OS 清理（`$TMPDIR` 重启后丢失），在 Report 中标注"Decision Log 不可用，以产物为准"，不阻塞 Report 生成也不视为错误。

```markdown
# Decision Report

## 概览

- **模式**：Auto
- **需求**：[一句话描述]
- **复杂度**：[评估的复杂度]
- **总裁决数**：N
- **按风险等级**：High: X / Medium: Y / Low: Z

## 裁决摘要

### High Risk 裁决（需要用户重点关注）

[列出所有 High 风险的裁决，按阶段排列]

### Medium Risk 裁决

[列出所有 Medium 风险的裁决]

### Low Risk 裁决

[列出所有 Low 风险的裁决]

## 流程完整性

- 建模审查：✅ 通过 / ⚠️ 有裁决 / ⚠️ 审查降级-用户授权
- Plan 审查（Epic 时）：✅ 通过 / ⚠️ 有裁决 / ⚠️ 审查降级-用户授权
- Spec 审查：✅ 通过 / ⚠️ 有裁决 / ⚠️ 审查降级-用户授权
- Scenario 审查：✅ 通过 / ⚠️ 有裁决 / ⚠️ 审查降级-用户授权
- Test 审查：✅ 通过 / ⚠️ 有裁决 / ⚠️ 审查降级-用户授权
- Red Run：✅ 全部红色 / ⚠️ 有异常
- Baseline Test Run：✅ 已记录 / ⚠️ 有预存在失败
- Spec 完整性校验：✅ 全部实现 / ⚠️ 有 ❌ 项（已升级用户）
- CI 验证：✅ 通过 / ❌ 失败

## 分模块裁决（Epic 时输出）

### Module: [模块名称]

- 裁决数：N（High: X / Medium: Y / Low: Z）
- 关键裁决：[列出该模块的 High/Medium 裁决摘要]

## Upstream Coverage（格式见 `guides/upstream-coverage.md`）

- 最终的 Upstream Coverage Matrix
- upstream 回修次数和每次的原因
- NOT APPLICABLE 条目清单及理由

## 建议用户复核的内容

[基于 High / Medium 风险裁决，建议用户重点复核哪些 Spec 规则、Scenario 或实现]
```

---

## 与标准模式的共存

- Auto 模式不改变标准模式的任何行为
- 不指定 `--auto` 时，默认走标准模式
- Auto 模式的所有审查步骤使用与标准模式相同的审查模板（`prompts/*.md`）
- 迭代修正机制仍适用，只是由 AI 替代人工做最终决策
