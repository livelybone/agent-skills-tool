---
name: test-design-and-implementation
description: "把 TechnicalSpec 转成可执行测试：先生成人类可读场景，再实现测试代码，覆盖主流程、关键规则和危险边界，不负责功能代码开发或 CI 门禁。触发词：设计测试、实现测试、写测试、test design、test implementation。"
metadata:
  version: 0.1.0
  tags:
    - testing
    - scenario-design
    - test-implementation
    - spec-driven
---

# Test Design And Implementation

把批准后的 `TechnicalSpec` 转成可执行测试：先产出人类可读场景，再把场景落实为测试代码。

## 适用场景

- 已有 `TechnicalSpec`，需要生成测试场景并实现测试代码
- 需要把关键业务规则、状态转换和危险边界转成可执行行为测试
- 需要为 `feature-implementation-from-spec` 提供已存在的测试约束
- 需要在功能实现前先建立红色测试约束（red-first）

## 必须材料

- 批准后的 `TechnicalSpec`
- 若 `TechnicalSpec` 的 `Upstream Models` 非 `N/A`：列出的全部建模文件
- 可写入测试文件的项目代码仓库
- 可解析的测试运行环境（已有测试框架或现有测试约定）
- 若被测模块文件不存在：允许先创建 implementation stub

若 `TechnicalSpec` 仍是 `Blocked`，本 skill 可以产出 `Blocked` 的场景稿以记录当前可见测试边界，但不得继续实现测试或执行 Red Run。

## 执行步骤

1. **检查 spec 就绪度**
   - 读取 `Goal / Scope / Non-Goals / Acceptance Signals / Rules / Interfaces / States / State Transitions / Non-Functional Constraints / Blocking Questions / Open Questions`
   - 若 `Upstream Models` 非 `N/A`：一并读取列出的建模文件，把其中的不变量、派生关系、关系约束和状态机当作测试设计上游输入
   - 若 `TechnicalSpec` 已是 `Blocked`：只允许产出 `Blocked` 场景稿，记录当前可见测试边界，然后回退到 `tech-spec-writing`
   - 若缺少会改变测试设计的关键信息：停止并回退到 `tech-spec-writing`

2. **生成测试场景**
    - 用 `assets/templates/test-scenarios.md` 产出人类可读场景
    - 场景优先级遵循：`CONTRACT > INTEGRATION > PROPERTY`
    - 上面是**测试形态优先级**；`references/test-checklist.md` 中的是**信息采集优先级**，两者用途不同
    - 每个保留场景都必须带最小追溯：`spec-ref` + `upstream-ref`
    - `upstream-ref` 的语法、`N/A` 规则和合法路径以 `../spec-driven-dev/guides/upstream-ref.md` 为唯一权威；测试阶段只负责按该规范落位，不在本 skill 内重定义
    - 至少覆盖：
     - 外部契约、权限边界、错误语义（若 spec 的 `Interfaces` 中存在）
     - 主要业务流程
     - 关键业务规则
     - 危险边界案例
     - 失败案例
     - 状态转换（若存在）
     - 非功能约束对应的可测试行为（若 spec 中存在）
     - `Acceptance Signals`
   - 从 `Rules`、`States`、`State Transitions` 以及 `Upstream Models`（若存在）系统推导边界与失败案例，不要只复述 spec 已经写出的示例
   - 危险边界默认至少检查：空值/缺失值、边界值、非法状态、权限边界，以及并发或重入风险（若相关）
   - 若 `Upstream Models` 存在不变量、派生关系或关系约束，至少保留对应的 `[PROPERTY]`、`[UNIT]` 或行为场景来保护这些语义
   - 主场景生成后，再做一轮 expansion pass：对照 `TechnicalSpec`、已生成场景，以及仓库中已存在的相关测试/实现（若存在），补出仍未覆盖的高价值场景
   - expansion pass 只补真实高风险缺口：遗漏的边界案例、契约风险、不变量或派生关系违规、并发或幂等性问题
   - 每个新增候选都必须能说明“不测试会有什么具体业务风险”；过不了 overtest 过滤的候选不保留

3. **审查测试场景（跨 agent）**
    - 必须通过 `multi-agent-loop` 发起独立审查，使用 `prompts/scenario-review.md` 作为审查指令正文模板来审查当前场景列表
    - 审查范围同时覆盖主场景和 expansion pass 补出的场景
    - 必查项：主流程、失败路径、危险边界是否遗漏；`[CRITICAL]` 标记是否合理；`CONTRACT / INTEGRATION / PROPERTY / UNIT` 类型是否合理；每个场景的 `upstream-ref` 是否真实且必要；是否越出 `TechnicalSpec` 或 `Upstream Models`；是否包含 overtest 场景；新增场景是否能说明不测试的具体业务风险
    - 若发现会改变测试边界的问题：回退到 `tech-spec-writing`
    - 若只是场景质量问题：先修场景并完成 findings 裁决，再进入测试实现

4. **过滤过度测试**
   - 删除以下场景：
      - 私有辅助函数测试
      - 实现细节耦合
      - 琐碎逻辑
      - 脆弱快照
      - 重复案例
   - 判断标准：删掉它后是否还有真实业务风险未覆盖；若没有，就不要保留

5. **建立 implementation stub（如需要）**
    - 被测模块文件不存在时，先创建 stub
    - stub 只保证 import 可解析和公开签名正确
    - stub 的公开契约必须与当前 spec 一致：导出的函数、类、类型、参数和返回类型都不能先行偏离
    - stub 中不得写任何业务逻辑，函数体统一 `throw new Error('not implemented')`
    - 可以补齐类型定义帮助测试通过类型检查，但不得借此提前实现行为
    - stub 内禁止条件逻辑、硬编码返回值、状态初始化、真实副作用或任何会让测试提前变绿的代码
    - 判断标准：如果删掉某段代码不影响 import 和类型解析，那它不属于 stub

6. **实现测试代码**
    - 把全部 `[CRITICAL]` 场景和主要业务场景落实为行为测试
    - 凡是因 `Interfaces`、错误语义、权限边界或 `Non-Functional Constraints` 被保留的必测场景，也必须落实为可执行测试
    - 测试类型严格跟随场景上的 `CONTRACT / INTEGRATION / PROPERTY / UNIT` 标记，不在实现阶段二次改判；若发现标记不合理，应回到场景修订
    - 测试文件位置和命名优先跟随仓库现有模式；若仓库没有现成约定，按 `references/repo-structure.md` 放置和命名
    - 测试应断言输入到输出/副作用，不断言内部状态存放位置
    - 每个场景都要有唯一 `Scenario ID`
    - 每个测试都要带最小追溯注释：`@scenario <Scenario ID>` + `@spec-ref <section>` + `@upstream <doc>#<anchor>`
    - 若场景的 `upstream-ref` 为 `N/A + <reason>`，测试也必须同步写出同样的 `@upstream N/A + <reason>`，不要静默省略
    - 禁止用 `skip` / `todo` / `xit` / `xtest` 代替未实现测试；测试必须形成真实的红色约束
    - 禁止用弱断言占位，例如只断言“不抛错”、`expect(true).toBe(true)`、或只验证导出/文件存在
    - 若发现测试翻译错误，可以修测试；但不得仅为了让测试变绿而削弱断言或改写已批准场景语义

7. **审查测试代码（跨 agent）**
    - 必须通过 `multi-agent-loop` 发起独立审查，使用 `prompts/test-review.md` 作为审查指令正文模板来审查当前测试文件
    - 审查目标是检查 `Test Scenarios -> Executable Tests` 的翻译是否完整、准确，并识别追溯断链、缺测、断言不完整、越界测试和 overtest
    - 必查项：每个测试的 `@scenario` 和 `@upstream` 是否存在且合法；是否与对应场景一致；每个场景是否都有对应测试；`[CRITICAL]` 场景的关键断言是否完整；测试是否越出场景边界；是否存在实现细节耦合或低价值冗余
    - 若发现问题会改变场景边界：回到场景修订，并在必要时重新执行场景审查
    - 若只是测试翻译质量问题：先修测试并完成 findings 裁决，再进入 Red Run

8. **执行 Red Run**
    - 即使已经完成场景审查和测试代码审查，Red Run 也不能省略；审查不能替代执行验证
    - 只在 `Status = Ready for implementation` 时运行
    - 只运行本次新增或修改的测试
    - 预期结果：当前 spec 范围内测试全部为红，且失败原因为 `not implemented` 或功能未实现
    - 若测试意外通过、import 错误或语法错误，先修测试/stub 再重跑

9. **交棒下游**
    - 把可执行测试套件交给功能实现阶段（当前是通用下游阶段；未来可由 `feature-implementation-from-spec` 消费）

## 产物与格式

### 主要产物

- **Test Scenarios**：使用 `assets/templates/test-scenarios.md`
- **Executable Test Suite**：项目中的实际测试文件

### 模板

模板单一真源：`assets/templates/test-scenarios.md`

关键字段：

- `Source Spec`
- `Scenario List`
- `Coverage Notes`
- `Filtered Out`
- `Status: Ready for implementation | Blocked`

Golden examples：见 `references/golden-examples.md`

### 场景格式

```markdown
[S-1][CRITICAL][INTEGRATION] 用户执行操作
→ 系统行为
↑ spec-ref: Acceptance Signals, Rules, State Transitions
↑ upstream-ref: domain/order.md#Invariant.Order.3
```

`spec-ref` 用来指向 `TechnicalSpec` 中的来源章节，保持场景到 spec 的最小追溯。每个场景必须带唯一 `Scenario ID`（如 `S-1`、`S-2`）。

`upstream-ref` 用来追溯对应的上游建模锚点；语法、路径约束和 `N/A` 规则见 `../spec-driven-dev/guides/upstream-ref.md`。

场景正文必须保持人类可读的行为描述，写“用户执行什么 -> 系统表现什么”，不要退化成测试函数名、suite 名或内部调用序列。

### 标记规则

- 每个保留场景都必须带测试类型标记：`[CONTRACT]`、`[INTEGRATION]`、`[PROPERTY]`，必要时 `[UNIT]`
- `[CONTRACT]`：API 响应结构、错误码、权限拒绝、对外承诺等外部契约
- `[INTEGRATION]`：主业务流程、跨模块协作、关键状态变化等行为路径
- `[PROPERTY]`：不变量、派生关系、任意输入下都应成立的规则
- `[UNIT]`：无法在更高层行为测试中稳定表达的单一规则或孤立验证
- 测试类型选择优先级：`CONTRACT > INTEGRATION > PROPERTY > UNIT`
- 高风险场景额外标 `[CRITICAL]`；默认重点判断五类风险：contract、money、permission、state transition、data integrity

### 验收标准

- `Status = Ready for implementation` 时：下游看到场景和测试后，能直接开始功能实现
- `Status = Ready for implementation` 时：`[CRITICAL]` 场景和主流程已落实为可执行测试
- 若 spec 存在外部契约、权限边界或错误语义，至少一个 `[CONTRACT]` 场景已落地
- 若 spec 存在可测试的非功能约束，相应场景已落地
- 仅有 stub、仅验证导出存在、或仅有场景稿而无测试，不算完成
- 所有必保留场景均已落实为可执行测试，而非只停留在场景稿
- `Status = Ready for implementation` 时：场景审查与测试代码审查均已完成，且 findings 已裁决
- `Status = Ready for implementation` 时：Red Run 已执行，失败原因符合预期
- `Status = Blocked` 时：只产出场景稿并明确阻塞原因，不进入测试实现或 Red Run
- 产物不依赖实现细节或私有 helper

## 质量门槛

> 遵循全局上下文中的“代码质量基础规范”

### 本 skill 特定检查

- [ ] `TechnicalSpec` 为 `Ready for test/design`，或当前产物明确走 `Blocked` 分支
- [ ] 场景覆盖 `Acceptance Signals`、主流程、关键规则和危险边界
- [ ] 已系统检查失败案例与危险边界，而不是只复述 spec 示例
- [ ] 若 `Interfaces` 中存在外部契约、权限或错误语义，至少有一个 `[CONTRACT]` 场景
- [ ] 若 `Non-Functional Constraints` 中存在可测试行为，相应场景已覆盖
- [ ] 若 `Upstream Models` 非 `N/A`，其中关键不变量、派生关系或关系约束已有对应场景
- [ ] 已通过 `multi-agent-loop` 完成场景跨 agent 审查，findings 已裁决
- [ ] 每个保留场景都有 `Scenario ID` 和 `spec-ref`
- [ ] 每个保留场景都有合法的 `upstream-ref`，或显式写出 `N/A + 具体理由`
- [ ] 每个保留场景都已落实为可执行测试，或当前产物明确处于 `Blocked` 分支
- [ ] 每个实现的测试都带 `@scenario`、`@spec-ref`、`@upstream` 最小追溯
- [ ] 测试文件位置和命名符合仓库现有约定，或符合 `references/repo-structure.md`
- [ ] 已通过 `multi-agent-loop` 完成测试代码跨 agent 审查，findings 已裁决
- [ ] 不存在 `skip` / `todo` / `xit` / `xtest`、弱断言或仅验证导出的占位测试
- [ ] 已过滤过度测试场景
- [ ] 测试行为而非内部实现
- [ ] stub 中无业务逻辑、无硬编码返回值、无条件分支、无真实副作用
- [ ] `Blocked` 时只产出场景稿，不进入测试实现或 Red Run
- [ ] `Ready for implementation` 时已执行 Red Run，且失败原因符合预期

## 验证方式

> 遵循全局上下文中的“验证方式通用流程”

### 本 skill 特定验证

1. 让阅读者回答：哪些场景最重要、哪些是危险边界？
2. 让阅读者回答：测试在保护哪些业务规则、验收信号和非功能约束？
3. 让阅读者回答：每个高风险场景分别由哪些测试保护，这些测试的 `@scenario` / `@upstream` 是否能串起完整追溯链？
4. 若 `Status = Ready for implementation`，运行本次新增测试，确认它们因未实现而失败，而非因测试本身损坏而失败
5. 若 `Status = Blocked`，确认阻塞原因已被清晰记录，且未进入测试实现或 Red Run
6. 若 1-5 中任一回答为否，说明场景或测试仍不够清晰

## 不覆盖范围

- 不负责需求澄清或技术文档编写
- 不负责功能实现代码
- 不负责覆盖率、变异测试、CI 或 branch protection
- 不负责为了通过测试而修改 `TechnicalSpec` 语义

## 覆盖声明

无

## 引用资料

- `assets/templates/test-scenarios.md` — 标准场景模板
- `prompts/scenario-review.md` — 场景跨 agent 审查提示
- `prompts/test-review.md` — 测试代码跨 agent 审查提示
- `../spec-driven-dev/guides/upstream-ref.md` — `upstream-ref` 语法与落位规范
- `references/repo-structure.md` — 测试文件位置与命名约定
- `references/test-checklist.md` — 场景生成与测试实现清单
- `references/golden-examples.md` — `Ready` / `Blocked` 示例
