# 提示模板 — 测试实现

基于批准的场景实现自动化测试。

## 前置引用

- **测试文件位置和命名**：见 `repo-structure.md`
- **测试类型优先级**：见 `scenario-format.md` > 测试类型标记
- **测什么/不测什么**：见 `testing-guide.md`

## 要求

- **按场景的测试类型标记（CONTRACT / INTEGRATION / PROPERTY / UNIT）决定测试类型**，不自行判断
- 优先行为级别测试
- 优先工作流的集成测试
- 当 API 模式稳定性重要时添加契约测试
- 当存在不变规则时添加属性测试
- 不要修改场景含义
- 不要削弱现有测试

## 测试原则

- 测试行为而非内部实现
- 避免与私有辅助函数绑定的脆弱测试
- 确保测试能验证场景中描述的行为
- 保持测试简洁、可读、可维护

### 断言行为契约，不断言实现路径

测试应该断言**输入 → 输出/副作用**（行为契约），不应该断言中间状态存放在哪个字段、经过哪条代码路径。

判断标准：**如果一次纯内部重构（不改变外部行为）导致大量测试失败，说明测试耦合了实现。**

**反模式：断言内部状态存放位置**

```ts
// ❌ 测的是"错误被写到了 store 的 sessionError 字段"——实现细节
await login(badCredentials);
expect(getState().sessionError?.code).toBe('INVALID_CREDENTIALS');

// ✅ 测的是行为契约——输入错误凭证，登录失败并返回正确错误码
await expect(login(badCredentials)).rejects.toThrow('INVALID_CREDENTIALS');
```

**反模式：直接塞 mock 状态来验证 UI**

```ts
// ❌ 锁死了"error 从 store 来"的实现路径
mockStore.setState({ sessionError: { code: 'INVALID_CODE' } });
expect(screen.getByText('验证码错误')).toBeVisible();

// ✅ 模拟用户行为 → 验证 UI 结果
await user.type(codeInput, '000000');
await user.click(submitButton);
expect(screen.getByText('验证码错误')).toBeVisible();
```

**写测试前问自己**：这个断言在纯内部重构后还会通过吗？如果把数据存储位置从 A 挪到 B（行为不变），这个测试会挂吗？如果会挂 → 测试耦合了实现，需要重写断言。

## 前置步骤：建立 Implementation Stub

**在写任何测试之前，先确认被测模块的文件存在且 import 路径可解析。**

如果实现文件不存在（或只有空文件），必须先创建 **Implementation Stub**：

- 创建正确路径的实现文件
- 导出所有测试会 import 的函数、类、类型
- **公开契约（函数签名、参数名/类型、返回类型、类结构）必须严格按照 spec 定义**——这是 stub 的核心约束
- 函数/方法**体内**一律写 `throw new Error('not implemented')`，不写任何业务逻辑
- 类型/接口可完整定义（帮助 TypeScript 通过类型检查）

**Stub 内绝对禁止出现：**

- ❌ 任何条件逻辑（`if` / `switch` / 三元）
- ❌ 任何 mock 数据或硬编码返回值（如 `return []`、`return 'disconnected'`）
- ❌ 任何状态初始化或状态机逻辑（即使是"最小化"版本）
- ❌ 任何认证、过滤、排序、失败注入等业务规则
- ❌ 任何真实 API 调用或副作用

**判断方法**：如果删掉这段代码不影响测试能否 import，那它就不属于 Stub，属于提前实现，必须删除。

目的：**让 import 路径可解析且契约正确**，使测试能跑起来（全部红）而不是在 import 阶段崩溃。

```ts
// ❌ 错误：签名/结构不符合 spec，破坏公开契约
export class CloudGatewayService {
  subscribe() { throw new Error('not implemented'); }  // 缺少参数
  status() { return 'disconnected'; }                  // 硬编码而非 spec 定义的状态机
  onStatusChange() { return () => {}; }                // 签名错误
}

// ✅ 正确：按 spec 定义公开契约，仅函数体用 throw 占位
export class CloudGatewayService {
  subscribe(channel: string, handler: MessageHandler): () => void {
    throw new Error('not implemented');
  }
  status(): ConnectionStatus {
    throw new Error('not implemented');
  }
  onStatusChange(listener: (status: ConnectionStatus) => void): () => void {
    throw new Error('not implemented');
  }
}
```

> **Stub 仅用于避免 import 失败，不计入测试完成度。** Stub 建立后必须立即继续写行为测试，不得在此阶段停下。

## 职责边界

**本阶段完成：Implementation Stub + 全部场景的行为测试。**

- Implementation Stub 只允许 `throw new Error('not implemented')`，不得写任何实际逻辑
- 禁止为了"让测试能跑通"而实现功能代码，这属于 Feature Implementation 阶段的工作
- 测试文件写完后，功能代码尚不存在或不完整是正常的——测试应该是红色的

## 测试完成度定义

**以下情况不算"测试完成"：**

- ❌ 仅建立了 stub 文件（import 可解析但无测试）
- ❌ 仅验证导出/文件存在（`expect(module).toBeDefined()`）
- ❌ 场景存在但测试用例未落地

**以下才算"测试完成"：**

- ✅ 所有 scenario（至少全部 `[CRITICAL]` 场景）已转化为可执行的行为测试
- ✅ 测试能运行（不在 import 阶段崩溃）
- ✅ 测试因实现未完成而失败（红色），而非被跳过

## 禁止事项

- **禁止使用 `skip` / `todo` / `xit` / `xtest` 代替"尚未实现"**
  - skip 让测试套件保持绿色，对实现没有任何约束力
  - 测试必须先红，实现才能让它变绿——这是 Spec-Driven 的核心约束机制
- 尚未实现的功能应写出完整断言，让 CI 在实现前保持红色状态
- **禁止写弱断言作为"临时测试"**——不得用 `expect(true).toBe(true)` 或只断言"不抛错"等方式先让测试通过，之后再加真实断言；必须一次写出完整、有约束力的断言

## 正确做法：先写完整断言，再实现

```ts
// ❌ 错误：skip 不形成约束; 不能写空的测试用例
it.skip("should reject invalid token", () => {
  // TODO
});

// ✅ 正确：写出完整断言，实现前测试为红，形成约束
it("should reject invalid token", () => {
  expect(() => validateToken("invalid")).toThrow(AuthError);
});
// → 此时无实现 → 测试红 → 开始实现 → 测试绿
```
