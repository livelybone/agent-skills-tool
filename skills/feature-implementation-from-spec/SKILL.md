---
name: feature-implementation-from-spec
description: "把批准后的 TechnicalSpec 和已实现测试落成生产级功能代码：先记录 baseline，再在不改规格语义的前提下完成实现、跑通范围内验证，并产出 DeliveredChange。触发词：实现功能、按 spec 开发、feature implementation、implement from spec。"
metadata:
  version: 0.1.0
  tags:
    - implementation
    - delivery
    - spec-driven
    - testing
---

# Feature Implementation From Spec

把批准后的 `TechnicalSpec` 和已实现测试落成生产级功能代码，并在交付前明确说明哪些能力已经实现、如何验证、是否仍有阻塞。

## 适用场景

- 已有 `TechnicalSpec`，且状态为 `Ready for implementation`
- 已有来自 `test-design-and-implementation` 的可执行测试，需要把红测变绿
- 需要按既有规则、契约、状态变化和测试约束实现功能
- 需要交付可评审、可进入 CI 的 `DeliveredChange`

## 必须材料

- 批准后的 `TechnicalSpec`
- 已存在且可运行的范围内测试
- 相关 `docs/models/<scenario>/<name>.md`（若上游已通过 `modeling-first` 建模，或 spec 明确引用了这些模型约束）
- 可写入实现代码的项目仓库
- 至少一个可运行的本地验证入口（测试、typecheck、lint、build 中与本次改动相关的命令）

若 `TechnicalSpec` 仍是 `Blocked`、测试不存在、或关键模型约束缺失且会改变实现边界，本 skill 必须停止并回退到上游，而不是自行猜测。

## 执行步骤

1. **检查实现前提**
    - 读取 `Goal / Scope / Non-Goals / Acceptance Signals / Rules / Interfaces / States / State Transitions / Non-Functional Constraints / Blocking Questions / Open Questions`
    - 确认状态为 `Ready for implementation`
    - 确认本次要消费的测试真实存在、覆盖当前 spec 主路径与每个声明的功能域，且带 `Scenario ID` 与 `@scenario` / `@spec-ref` / `@upstream` 最小追溯
    - 若测试缺少 `Scenario ID`、`@scenario`、`@spec-ref` 或 `@upstream`，停止实现并回退到 `test-design-and-implementation`
   - 若某个 spec 功能域没有对应的可执行测试，停止实现并回退到 `test-design-and-implementation`
   - 若仍存在 `Blocking Questions`，或存在会改变实现语义的 spec 歧义：停止实现并回退到 `tech-spec-writing`
   - 若 spec、测试与模型之间存在矛盾：停止实现，回退到上游修订

2. **记录 Baseline Test Run**
   - 在写实现代码前，先运行当前 spec 范围内的全部测试
   - 记录失败项，并区分：
     - 属于当前 spec 范围的失败：这是本次必须消除的工作，不算预存在问题
     - 不属于当前 spec 范围的失败：记录为预存在问题，但不要顺手修 unrelated 问题

3. **锁定实现范围**
    - 从 spec 中提取本次必须交付的功能域、服务、组件或流程
    - 对照测试中的 `@scenario` / `@spec-ref` / `@upstream` 与模型中的 `upstream-ref`，确认每类能力的约束来源
    - 找出仍是 stub、`throw new Error('not implemented')` 或尚未覆盖的生产代码位置

4. **实现生产级代码**
   - 只修改当前 spec 范围内的实现代码
   - 保持外部契约稳定，除非 spec 明确要求变更
   - 不为了让测试变绿而改写已批准测试；若怀疑测试错误，停止并升级
   - 不允许以硬编码、临时分支或保留 stub 的方式宣称完成

5. **运行范围内验证**
   - 反复运行本次范围内测试，直到当前 spec 范围内失败全部消除
   - 运行与改动相关的本地验证命令（如 typecheck / lint / build）
   - 确认本次范围内不再残留 stub、`not implemented` 或明显未落地的 spec 能力

6. **产出交付报告**
   - 使用 `assets/templates/delivered-change.md`
   - 输出 `Spec Completeness Matrix`：逐条列出 spec 的功能域、对应测试和实现状态
   - 输出 `Upstream Coverage Matrix`：逐条列出相关模型锚点、独立的 `Scenario ID`（若无对应场景则显式写 `N/A`）与精确 `spec-ref`、测试位置、实现位置和状态
   - 若某条只能标记 `⚠️ NOT APPLICABLE + 理由`，理由必须具体且与 spec 边界一致

7. **交棒下游**
   - 向评审或 CI 交付 `DeliveredChange`
   - 若状态为 `Blocked`，明确指出阻塞原因与未完成项，不交付伪完成结果

## 产物与格式

### 主要产物

- **DeliveredChange**：使用 `assets/templates/delivered-change.md`
- **Production Code Changes**：项目中的实际实现代码

### 模板

模板单一真源：`assets/templates/delivered-change.md`

关键字段：

- `Source Spec`
- `Source Tests`
- `Source Models`
- `Baseline Failures`
- `Changed Files`
- `Spec Completeness Matrix`
- `Upstream Coverage Matrix`
- `Validation`
- `Blockers`
- `Unfinished Items`
- `Residual Risks`
- `Status: Delivered | Blocked`

Golden examples：见 `references/golden-examples.md`

### 验收标准

- 当前 spec 范围内的测试已从 baseline 失败变为通过
- spec 中定义的每个功能域、服务或组件都有生产级实现，而非 stub
- spec 中定义的每个功能域、服务或组件都有真实的对应测试证据，而不是空列或占位符
- 实现未越界修改需求、技术文档或已批准测试的语义
- 相关模型锚点在 `Upstream Coverage Matrix` 中无遗漏
- `Status = Delivered` 时，没有当前 spec 范围内遗留的 `❌` 项
- `Status = Blocked` 时，阻塞原因和未完成项足以让上游知道该回退哪里修订

## 质量门槛

> 遵循全局上下文中的“代码质量基础规范”

### 本 skill 特定检查

- [ ] `TechnicalSpec` 为 `Ready for implementation`
- [ ] 已执行 Baseline Test Run，并区分范围内失败与无关失败
- [ ] 当前消费的测试带 `Scenario ID` 与 `@scenario` / `@spec-ref` / `@upstream` 最小追溯；若缺失，已停止并回退上游
- [ ] 每个 spec 功能域都有对应的可执行测试；若缺失，已停止并回退到 `test-design-and-implementation`
- [ ] 若仍存在 `Blocking Questions` 或会改变实现语义的 spec 歧义，已停止并回退到 `tech-spec-writing`
- [ ] 只修改当前 spec 范围内的实现代码，未擅自改写批准测试
- [ ] 每个 spec 功能域都有生产级实现，没有 stub 残留
- [ ] 每个相关模型锚点都在 `Upstream Coverage Matrix` 中被覆盖，并保留精确的 `Scenario ID`（或显式 `N/A`）与 `spec-ref`；若 `NOT APPLICABLE`，也必须写明对应的 `spec-ref`
- [ ] 本次相关验证命令已运行，结果已记录
- [ ] 若遇到 spec / test / model 语义冲突，已停止并显式阻塞，而不是自行猜测

## 验证方式

> 遵循全局上下文中的“验证方式通用流程”

### 本 skill 特定验证

1. 让阅读者回答：这次到底实现了哪些功能域、哪些没有实现？
2. 让阅读者回答：每个功能域分别由哪些测试和实现位置证明？
3. 让阅读者回答：baseline 中属于当前 spec 范围的失败是否都被消除？
4. 若存在模型约束，让阅读者回答：哪些锚点被覆盖、哪些是 `NOT APPLICABLE`，为什么？
5. 若 1-4 中任一回答为否，说明当前交付仍不够清晰

## 不覆盖范围

- 不负责需求澄清、领域建模或技术文档编写
- 不负责测试设计；只消费已批准测试
- 不负责 coverage gate、mutation testing、branch protection 或 PR 流程
- 不负责以“改测试”替代实现，或以“改 spec”掩盖实现问题

## 覆盖声明

无

## 引用资料

- `assets/templates/delivered-change.md` — 标准交付模板
- `references/implementation-checklist.md` — 实现前后检查清单
- `references/golden-examples.md` — `Delivered` / `Blocked` 示例
