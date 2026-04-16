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
- 可写入测试文件的项目代码仓库
- 可解析的测试运行环境（已有测试框架或现有测试约定）
- 若被测模块文件不存在：允许先创建 implementation stub

若 `TechnicalSpec` 仍是 `Blocked`，本 skill 可以产出 `Blocked` 的场景稿以记录当前可见测试边界，但不得继续实现测试或执行 Red Run。

## 执行步骤

1. **检查 spec 就绪度**
   - 读取 `Goal / Scope / Non-Goals / Acceptance Signals / Rules / Interfaces / States / State Transitions / Non-Functional Constraints / Blocking Questions / Open Questions`
   - 若 `TechnicalSpec` 已是 `Blocked`：只允许产出 `Blocked` 场景稿，记录当前可见测试边界，然后回退到 `tech-spec-writing`
   - 若缺少会改变测试设计的关键信息：停止并回退到 `tech-spec-writing`

2. **生成测试场景**
    - 用 `assets/templates/test-scenarios.md` 产出人类可读场景
    - 场景优先级遵循：`CONTRACT > INTEGRATION > PROPERTY`
    - 上面是**测试形态优先级**；`references/test-checklist.md` 中的是**信息采集优先级**，两者用途不同
     - 至少覆盖：
     - 外部契约、权限边界、错误语义（若 spec 的 `Interfaces` 中存在）
     - 主要业务流程
     - 关键业务规则
     - 危险边界案例
     - 状态转换（若存在）
     - 非功能约束对应的可测试行为（若 spec 中存在）
     - `Acceptance Signals`

3. **过滤过度测试**
   - 删除以下场景：
     - 私有辅助函数测试
     - 实现细节耦合
     - 琐碎逻辑
     - 脆弱快照
     - 重复案例
   - 判断标准：删掉它后是否还有真实业务风险未覆盖；若没有，就不要保留

4. **建立 implementation stub（如需要）**
   - 被测模块文件不存在时，先创建 stub
   - stub 只保证 import 可解析和公开签名正确
   - stub 中不得写任何业务逻辑，函数体统一 `throw new Error('not implemented')`

5. **实现测试代码**
   - 把全部 `[CRITICAL]` 场景和主要业务场景落实为行为测试
   - 凡是因 `Interfaces`、错误语义、权限边界或 `Non-Functional Constraints` 被保留的必测场景，也必须落实为可执行测试
   - 测试应断言输入到输出/副作用，不断言内部状态存放位置
   - 每个场景都要有唯一 `Scenario ID`
   - 每个测试都要带最小追溯注释：`@scenario <Scenario ID>` + `@spec-ref <section>`

6. **执行 Red Run**
   - 只在 `Status = Ready for implementation` 时运行
   - 只运行本次新增或修改的测试
   - 预期结果：当前 spec 范围内测试全部为红，且失败原因为 `not implemented` 或功能未实现
   - 若测试意外通过、import 错误或语法错误，先修测试/stub 再重跑

7. **交棒下游**
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
```

`spec-ref` 用来指向 `TechnicalSpec` 中的来源章节，保持场景到 spec 的最小追溯。每个场景必须带唯一 `Scenario ID`（如 `S-1`、`S-2`）。

### 验收标准

- `Status = Ready for implementation` 时：下游看到场景和测试后，能直接开始功能实现
- `Status = Ready for implementation` 时：`[CRITICAL]` 场景和主流程已落实为可执行测试
- 若 spec 存在外部契约、权限边界或错误语义，至少一个 `[CONTRACT]` 场景已落地
- 若 spec 存在可测试的非功能约束，相应场景已落地
- 所有必保留场景均已落实为可执行测试，而非只停留在场景稿
- `Status = Ready for implementation` 时：Red Run 已执行，失败原因符合预期
- `Status = Blocked` 时：只产出场景稿并明确阻塞原因，不进入测试实现或 Red Run
- 产物不依赖实现细节或私有 helper

## 质量门槛

> 遵循全局上下文中的“代码质量基础规范”

### 本 skill 特定检查

- [ ] `TechnicalSpec` 为 `Ready for test/design`，或当前产物明确走 `Blocked` 分支
- [ ] 场景覆盖 `Acceptance Signals`、主流程、关键规则和危险边界
- [ ] 若 `Interfaces` 中存在外部契约、权限或错误语义，至少有一个 `[CONTRACT]` 场景
- [ ] 若 `Non-Functional Constraints` 中存在可测试行为，相应场景已覆盖
- [ ] 每个保留场景都有 `Scenario ID` 和 `spec-ref`
- [ ] 每个保留场景都已落实为可执行测试，或当前产物明确处于 `Blocked` 分支
- [ ] 已过滤过度测试场景
- [ ] 测试行为而非内部实现
- [ ] stub 中无业务逻辑
- [ ] `Blocked` 时只产出场景稿，不进入测试实现或 Red Run
- [ ] `Ready for implementation` 时已执行 Red Run，且失败原因符合预期

## 验证方式

> 遵循全局上下文中的“验证方式通用流程”

### 本 skill 特定验证

1. 让阅读者回答：哪些场景最重要、哪些是危险边界？
2. 让阅读者回答：测试在保护哪些业务规则、验收信号和非功能约束？
3. 若 `Status = Ready for implementation`，运行本次新增测试，确认它们因未实现而失败，而非因测试本身损坏而失败
4. 若 `Status = Blocked`，确认阻塞原因已被清晰记录，且未进入测试实现或 Red Run
5. 若 1-4 中任一回答为否，说明场景或测试仍不够清晰

## 不覆盖范围

- 不负责需求澄清或技术文档编写
- 不负责功能实现代码
- 不负责覆盖率、变异测试、CI 或 branch protection
- 不负责为了通过测试而修改 `TechnicalSpec` 语义

## 覆盖声明

无

## 引用资料

- `assets/templates/test-scenarios.md` — 标准场景模板
- `references/test-checklist.md` — 场景生成与测试实现清单
- `references/golden-examples.md` — `Ready` / `Blocked` 示例
