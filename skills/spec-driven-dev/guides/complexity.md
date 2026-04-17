# 复杂度分级标准

复杂度不会改变 `spec-driven-dev` 的 13 步主阶段顺序；它只决定**标准模式下各 Review 阶段是否执行**，以及人工 gate 粒度。

Auto 模式下所有 Review 阶段默认强制执行，不受复杂度影响（详见 `workflows/auto.md`）。

## 不随复杂度变化的内容

- `modeling-first` 仍是硬前置，除非建模豁免已被批准
- 建模豁免审查（`prompts/exemption-review.md`）只要走豁免就强制执行，不受复杂度影响
- Epic 仍必须先产出并校验 `plan.md`
- Epic 的 Plan Review 在任何模式和任何复杂度下都**强制执行**
- `tech-spec-writing`、`test-design-and-implementation`、`feature-implementation-from-spec` 的主阶段顺序不变
- worker 自己定义的硬 gate、红测约束、baseline、验证命令不因复杂度跳过
- 机械校验脚本（`check-plan-structure.sh`、`check-upstream-coverage.sh`）始终执行

## 标准模式下 Review 阶段的触发规则

| Review 阶段 | Trivial | Simple | Medium | Complex |
|------|---------|--------|--------|---------|
| 步骤 4 Modeling Review | 可跳过（人工快速确认） | 人工审查为主，独立审查可选 | 建议执行 | 强烈建议执行 |
| 步骤 4' Modeling Exemption Review | 强制执行 | 强制执行 | 强制执行 | 强制执行 |
| 步骤 6 Plan Review（Epic） | N/A | N/A | 强制执行 | 强制执行（建议多轮） |
| 步骤 8 Spec Review | 可跳过（人工快速确认） | 人工审查为主，独立审查可选 | 建议执行 | 强烈建议执行 |
| 步骤 10 Test Review | 可跳过（人工快速确认） | 人工审查为主，独立审查可选 | 建议执行 | 强烈建议执行 |
| 步骤 12 Implementation Review | 可跳过（正常验证即可） | 人工审查为主，独立审查可选 | 建议执行 | 强烈建议执行（高风险模块尤其） |

**跳过的条件与留痕**：

- "可跳过" 意味着允许跳过 `multi-agent-loop` 独立审查，但人工确认仍然必须完成
- 所有跳过必须在 Decision Log 中写明：`跳过理由：<complexity 判定> + <具体理由>`
- 跳过 ≠ 忽略：跳过仅指不启动独立 runner；各阶段的机械校验（如 Red Run、check-upstream-coverage.sh）仍要执行
- 若跳过后下游阶段暴露出本应在 Review 阶段发现的问题，须在复盘时调整该模块的复杂度评级

## 各级别示例

- **Trivial**：局部小改动，不引入新规则或新状态
- **Simple**：单模块、规则有限、边界清晰的功能补充
- **Medium**：存在多条规则、失败路径、状态变化或权限边界
- **Complex**：跨模块、多契约、多状态机，或高风险领域（资金/权限/数据一致性）

## Epic 说明

Epic 不是单一复杂度档位，而是需要先建模、再 plan、再按模块推进的多模块需求。

- Epic 内每个模块都可以再单独标记 `Trivial / Simple / Medium / Complex`
- `plan.md` 中的复杂度字段服务于模块级 Review 触发判断和推进优先级
- 模块复杂度不影响 Epic 维度的 Modeling Review 和 Plan Review（Epic 维度审查的触发规则看整个 Epic 的规模，不看单模块）
