# 迭代修正机制

任何阶段发现问题，允许回退上一步。

## 跨 agent 审查 Spec 后发现问题

→ 人根据 AI 审查报告修订 Spec → 可选：再次 跨 agent 审查 → 人确认

## Scenario 生成后发现 Spec 有歧义

→ 标记问题 → 人修订 Spec → 可选：跨 agent 审查 Spec → AI 重新生成 Scenario → 人重新审查

## 跨 agent 审查 Scenario 后发现 Spec 遗漏

→ 人修订 Spec → AI 重新生成 Scenario → 可选：跨 agent 审查 Scenario → 人重新审查

## 人工 Scenario 审查发现问题（无 跨 agent 审查时）

→ 人标记问题 → 区分是 Spec 遗漏还是 Scenario 生成问题：
  - Spec 遗漏 → 人修订 Spec → AI 重新生成 Scenario → 人重新审查
  - Scenario 生成问题 → AI 修正 Scenario → 人重新审查

## Test 实现后发现 Scenario 无法自动化

→ 与人确认 → 调整 Scenario 或测试策略 → 重新实现

## Test Review 发现 Scenario → Test 翻译不完整

→ 修复测试断言 → 重新执行 Test Review

## Human Test Review 发现测试策略有问题

→ 人修订测试策略 → AI 重新实现测试 → 重新 Test Review

## Feature 实现后发现 Spec 逻辑矛盾

→ 停止实现 → 人修订 Spec → AI 重新生成 Scenario/Test/Feature

## CI 失败

→ 分析失败原因 → 判断是测试问题还是实现问题 → 修正 → 重新验证

## Spec 编写时发现 Plan 模块边界错误

→ 停止写 Spec → 人修订 Plan（调整模块边界或拆分模块）→ Human Plan Review → 重新编写受影响模块的 Spec

## Test / Feature 实现时发现模块间契约冲突

→ 停止实现 → 确认根因是 Plan 的契约定义有歧义（而非单模块 Spec 问题）→ 人修订 Plan 中相关模块的"产出契约"→ 受影响模块重新走 Spec → Scenario → Test → Feature

## Plan 回退限制

**Plan 回退的触发条件须严格限定**，以下情况不应回退 Plan：

- 模块内部实现细节变化（在 Spec 层处理）
- 边界案例补充（在 Scenario 层处理）
- 接口签名调整但语义不变（在 Spec 层处理）

## Auto 模式下的迭代修正

上述所有回退规则同样适用于 Auto 模式，区别在于：

- "人修订"替换为"AI 裁决并记录 Decision Log"
- "与人确认"替换为"AI 自主裁决"——包括"Scenario 无法自动化"场景：AI 自行调整 Scenario 或测试策略，记录 Decision Log
- AI 可在裁决权限范围内修改 Spec/Scenario/Plan（详见 workflow-auto.md > 裁决权限）
- 超出裁决权限的修改仍必须升级给用户
- 每次修改必须记录 Decision Log，包含变更前后对照
