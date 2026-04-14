# 测试指南（唯一定义点）

> **本文件是"测什么 / 不测什么 / 怎么测"的唯一权威定义。** 各 prompt 文件引用本文件，不得各自重新定义。

---

## 测试什么（按优先级）

1. 契约稳定性（API 响应字段、事件负载结构、错误代码、权限行为）
2. 主要业务流程（创建、支付、取消、退款等端到端工作流）
3. 关键业务规则
4. 危险边界案例
5. 不变量/属性（订单总额永远不能为负、库存永远不能为负、不能有两个最终状态）

只有在保护行为时，高覆盖率才有价值。

---

## 不测什么 — Overtest 过滤清单

以下类型的测试应在 Scenario 生成和 Test 审查阶段被过滤掉：

| 类别 | 说明 | 判断标准 |
|------|------|---------|
| **私有辅助函数** | 测试行为契约，不测内部 helper | 如果函数未导出，不应被测试直接 import |
| **实现细节耦合** | 断言依赖内部状态存放位置、具体代码路径 | 纯内部重构（不改外部行为）会导致测试失败 → 耦合了实现 |
| **琐碎逻辑** | getter/setter、简单赋值、类型转换 | 无业务风险的操作 |
| **脆弱快照** | 序列化快照在任意格式变动时误报 | 完整输出结构匹配，内部重构即失败 |
| **重复案例** | 多个场景测试本质相同的行为路径 | 仅输入值不同且不构成边界 |

**过度测试与覆盖不足同等有害——它增加维护成本、降低信噪比、在重构时产生大量误报。**

### 过滤应用时机

- **Scenario 生成**：AI 生成后自查，删除属于上述类别的场景
- **Scenario 审查**：审查员逐条检查，标记疑似过度测试
- **Test 审查**：审查员检查测试代码中的实现细节耦合
- **Test 扩展**：每个建议场景必须通过过滤门槛才予提出

### 行为契约 vs 实现路径

测试应断言 **输入 → 输出/副作用**（行为契约），不应断言中间状态存放在哪个字段、经过哪条代码路径。

**反模式：断言内部状态存放位置**

```ts
// ❌ 测的是"错误被写到了 store 的 sessionError 字段"——实现细节
await login(badCredentials);
expect(getState().sessionError?.code).toBe('INVALID_CREDENTIALS');

// ✅ 测的是行为契约——输入错误凭证，登录失败并返回正确错误码
await expect(login(badCredentials)).rejects.toThrow('INVALID_CREDENTIALS');
```

**写测试前问自己**：这个断言在纯内部重构后还会通过吗？如果会挂 → 测试耦合了实现，需要重写断言。

---

## Implementation Stub 规则

**在写任何测试之前，先确认被测模块的文件存在且 import 路径可解析。**

如果实现文件不存在（或只有空文件），必须先创建 **Implementation Stub**：

- 创建正确路径的实现文件
- 导出所有测试会 import 的函数、类、类型
- **公开契约（函数签名、参数名/类型、返回类型、类结构）必须严格按照 spec 定义**——这是 stub 的核心约束
- 函数/方法**体内**一律写 `throw new Error('not implemented')`，不写任何业务逻辑
- 类型/接口可完整定义（帮助 TypeScript 通过类型检查）

### Stub 内绝对禁止

- ❌ 任何条件逻辑（`if` / `switch` / 三元）
- ❌ 任何 mock 数据或硬编码返回值（如 `return []`、`return 'disconnected'`）
- ❌ 任何状态初始化或状态机逻辑
- ❌ 任何认证、过滤、排序、失败注入等业务规则
- ❌ 任何真实 API 调用或副作用

**判断方法**：如果删掉这段代码不影响测试能否 import，那它就不属于 Stub，属于提前实现，必须删除。

### Stub 示例

```ts
// ❌ 错误：签名/结构不符合 spec，破坏公开契约
export class CloudGatewayService {
  subscribe() { throw new Error('not implemented'); }  // 缺少参数
  status() { return 'disconnected'; }                  // 硬编码
}

// ✅ 正确：按 spec 定义公开契约，仅函数体用 throw 占位
export class CloudGatewayService {
  subscribe(channel: string, handler: MessageHandler): () => void {
    throw new Error('not implemented');
  }
  status(): ConnectionStatus {
    throw new Error('not implemented');
  }
}
```

> **Stub 仅用于避免 import 失败，不计入测试完成度。** Stub 建立后必须立即继续写行为测试。

---

## Red Run 协议

**无论是否执行了跨 agent 审查 Test，Red Run 都必须执行。** 标准模式和 Auto 模式均适用。

### 作用域

Red Run **只运行当前 Spec 范围内新增/修改的测试**，不运行仓库全量测试（全量由 CI 验证负责）。

- 新项目（无存量代码）：所有测试即为当前 Spec 范围内的测试
- 增量开发（有存量代码）：只运行本轮新增的测试文件/测试用例

### 预期结果

当前 Spec 范围内的测试**全部失败**，且失败原因符合预期：

- **新建 Stub 的模块**：失败原因应为 `not implemented`
- **已有实现的模块（增量开发）**：失败原因应为功能未实现或行为不符合新 Spec

### 异常处理

- 测试意外通过 → 测试有问题（断言不充分），修复后重新运行
- 失败原因是 import 错误、语法错误等非业务原因 → 测试或 stub 有问题，修复后重新运行

---

## 测试完成度定义

**以下情况不算"测试完成"：**

- ❌ 仅建立了 stub 文件（import 可解析但无测试）
- ❌ 仅验证导出/文件存在（`expect(module).toBeDefined()`）
- ❌ 场景存在但测试用例未落地

**以下才算"测试完成"：**

- ✅ 所有 scenario（至少全部 `[CRITICAL]` 场景）已转化为可执行的行为测试
- ✅ 测试能运行（不在 import 阶段崩溃）
- ✅ 测试因实现未完成而失败（红色），而非被跳过

---

## 禁止事项

- **禁止使用 `skip` / `todo` / `xit` / `xtest` 代替"尚未实现"**——skip 让测试套件保持绿色，对实现没有任何约束力。测试必须先红，实现才能让它变绿
- **禁止写弱断言作为"临时测试"**——不得用 `expect(true).toBe(true)` 或只断言"不抛错"等方式先让测试通过
- **禁止在测试失败时修改测试**——测试是从人工审批的 Scenario 派生的规格约束，改测试等于绕过审批。测试失败时只能修改实现代码

```ts
// ❌ 错误：skip 不形成约束
it.skip("should reject invalid token", () => { /* TODO */ });

// ✅ 正确：写出完整断言，实现前测试为红
it("should reject invalid token", () => {
  expect(() => validateToken("invalid")).toThrow(AuthError);
});
```
