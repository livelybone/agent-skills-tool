# 提示模板 — 功能实现

根据 Spec、批准的测试、**建模文件**实现功能。

## 必须输入（硬性前提）

- Spec（业务规范）
- 批准的测试用例（含 `@scenario` / `@upstream` 追溯字段）
- **建模文件**（`model.md` / `epic-model.md`，由 `modeling-first` 产出）——必须提供
- Scenario 列表（含 `upstream-ref`）

若缺任一，停止实现，向人工报告。

## 前置步骤：Baseline Test Run

**在写任何实现代码之前**，必须先执行：

1. **运行当前 Spec 范围内的全部测试**，记录失败列表（suite 名 + 失败原因）
2. 将此列表作为 **baseline**，明确区分：
   - **baseline 失败 + 属于当前 Spec 范围** → 这是你必须实现的工作，不是"预存在问题"
   - **baseline 失败 + 不属于当前 Spec 范围** → 真正的预存在问题，记录但不负责
3. 实现完成后，baseline 列表交由 CI 验证（步骤 6.1 Baseline 对比）

**禁止将当前 Spec 范围内的测试失败归为"预存在问题"而跳过实现。**

## 要求

- 保持最小范围
- 避免无关重构
- 除非 Spec 另有说明，否则保留现有契约
- 实现当前 Spec 范围内的所有功能域，测试验证交由 CI 验证（步骤 6）
- 在改变行为之前暴露 Spec 歧义

## 实现原则

- 遵循 Spec 的每一条规则
- 实现必须覆盖当前 Spec 范围内的所有功能域
- 不要添加 Spec 中未要求的功能
- 不要修改无关代码
- 保持代码简洁、可读、可维护

## Spec 完整性 + Upstream Coverage 校验

实现完成后，必须输出**两张矩阵**：

### 矩阵 1：Spec 完整性矩阵

逐条对照 Spec 中定义的所有功能域/服务/组件，确认：

1. 每个功能域都有对应的**生产级实现**（不是 stub、不是 `throw new Error('not implemented')`）
2. 每个功能域都有对应的测试 suite（测试是否通过由 CI 验证判定）
3. 没有遗漏的功能域

输出格式：

```
| 功能域 | 对应测试 suite | 实现状态 | 备注 |
|--------|---------------|---------|------|
| ServiceA | ServiceA.test.ts | ✅ 生产级 | |
| ServiceB | ServiceB.test.ts | ❌ 仍为 stub | 需要安装 native 依赖，待确认 |
```

### 矩阵 2：Upstream Coverage Matrix

逐条对照**建模文件**中声明的所有实体/关系/不变量/派生关系，确认每条都有对应的 Spec 场景 / Test / Impl：

```
| upstream 条目 | Spec 场景 | Test 位置 | Impl 位置 | 状态 |
|--------------|----------|----------|----------|------|
| model.md#Invariant.Order.1 | S-1 [PROPERTY] | tests/order.prop.test.ts:42 | src/order.ts:validate | ✅ |
| model.md#Derivation.Order.total | S-5 [UNIT] | tests/order.unit.test.ts:60 | src/order.ts:38 | ✅ |
| model.md#Invariant.Order.5 | S-3 [CRITICAL][INTEGRATION] | tests/order.int.test.ts:80 | src/order.ts:cancel | ✅ |
| model.md#Rel.Order-OrderItem | — | — | — | ⚠️ NOT APPLICABLE + 理由 |
```

**矩阵规则**：

- 建模文件**每一条**必须在矩阵中出现（包括实体属性、关系、不变量、派生关系）
- 每条的状态必须是 `✅`（完整覆盖）或 `⚠️ NOT APPLICABLE + <具体理由>`
- 不接受 `❌` 或遗漏——出现即 DoD 不通过
- 每条的 Spec/Test/Impl 位置必须是真实存在的引用；虚假引用直接 DoD 失败
- Spec/Test/Impl 位置格式：**`file.ext:<lineno>` 或 `file.ext:<identifier>`**。复杂符号（如 `get total()`、`Class.method`、含空格或括号的符号）**必须**用行号形式——否则机械校验会判定为 INVALID SUFFIX

### 校验流程

- 两张矩阵均由 AI 自检输出
- 若矩阵 1 存在任何 ❌ 项或矩阵 2 存在任何遗漏/虚假引用，**必须升级给人工确认**，不得自行决定跳过
- 因客观原因无法实现的功能域或无法覆盖的 upstream 条目，必须向人工报告并获得确认

## 禁止事项

- **禁止在测试失败时修改测试**——测试是从人工审批的 Scenario 派生的规格约束，改测试等于绕过审批、篡改规格
- 测试失败时，只能修改实现代码，不得触碰测试文件
- **禁止"临时实现优先"**——不得先写硬编码或最小存根让测试变绿，再替换为真实实现；必须一次写出覆盖当前 Spec 范围内所有功能域的生产级代码
- **禁止部分实现后宣告完成**——Spec 中定义的所有功能域必须全部实现，不得只实现"容易的"部分而跳过其余

## 开发过程中测试失败时的处理流程

实现过程中可以运行测试获取反馈，遇到失败时按以下流程处理（最终通过验证由 CI 验证步骤 6 负责）：

1. **实现有误** → 修改实现代码
2. **测试本身有误** → 停止，向人工报告，回溯到 Scenario 层确认后再改测试
3. **需求变更导致测试过时** → 走完整流程：Spec → Scenario（人工审批）→ 更新测试 → 再实现

## 如果发现 Spec 问题

- 停止实现
- 明确指出 Spec 的歧义或矛盾
- 等待人工确认和修订
- 不要自行猜测 Spec 的意图
