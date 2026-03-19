# 提示模板 — 测试实现

基于批准的场景实现自动化测试。

## 测试文件命名与放置规则

### 目录结构

**前置步骤：先判断项目类型，再选择对应的目录结构。**

---

#### 单包项目（non-monorepo）

| 类型 | 放置位置 |
|------|---------|
| UNIT / PROPERTY | colocate，紧邻被测文件 |
| CONTRACT | `tests/contract/`，子目录镜像 `src/` |
| INTEGRATION | `tests/integration/`，子目录镜像 `src/` |

```
src/
  services/
    UserService.ts
    UserService.test.ts          ← UNIT / PROPERTY
tests/
  contract/
    services/UserService.test.ts ← CONTRACT
  integration/
    services/UserService.test.ts ← INTEGRATION
```

---

#### Monorepo

测试必须放在**被测代码所属的 workspace 内**，不得跨 workspace 聚合到仓库根目录。每个 workspace 内部结构与单包项目相同。

**跨 workspace 的契约测试**：放在**消费方 workspace** 的 `tests/contract/`，由消费方负责验证上游是否满足自己的期望。上游变更时消费方测试报错，责任归属清晰。

```
apps/mobile/
  tests/
    contract/
      AuthToken.test.ts  ← mobile 验证 libs/services 的 AuthToken 契约
```

| 类型 | 放置位置 |
|------|---------|
| UNIT / PROPERTY | workspace 内 colocate，紧邻被测文件 |
| CONTRACT | workspace 内 `tests/contract/`，子目录镜像 `src/` |
| INTEGRATION | workspace 内 `tests/integration/`，子目录镜像 `src/` |

```
apps/mobile/                         ← workspace
  src/
    services/
      UserService.ts
      UserService.test.ts            ← UNIT / PROPERTY
  tests/
    contract/
      services/UserService.test.ts   ← CONTRACT
    integration/
      services/UserService.test.ts   ← INTEGRATION

libs/services/                       ← 另一个 workspace，结构相同
  src/
    AuthToken.ts
    AuthToken.test.ts
  tests/
    contract/
      AuthToken.test.ts
```

---

**写完测试后，必须执行以下自检：**

```
1. [monorepo] 测试文件是否在被测代码所属的 workspace 内？（不在则移动）
2. 文件里所有 test case 的类型是否一致？（混合则拆分）
3. 文件路径是否与测试类型匹配？（CONTRACT 在 tests/contract/，UNIT/PROPERTY 在 src/ 旁）
```

### 文件命名规则

**测试文件名必须与被测文件名保持一致，只在扩展名前加 `.test` 或 `.spec`。**

**前置步骤：在写测试前，先检查项目里已有的测试文件命名模式（`.test.ts` 还是 `.spec.ts`，目录结构如何组织），与现有模式保持一致。**

`__tests__/` 目录仅用于存放测试辅助工具（helpers、fixtures、mocks、test utilities），不存放测试文件本身。

禁止：
- ❌ [monorepo] 将测试放到仓库根 `tests/` 目录（应放在各自 workspace 内）
- ❌ 将 UNIT / PROPERTY 测试放到 `tests/` 或 `__tests__/` 目录（应 colocate 在 `src/` 中）
- ❌ 将 CONTRACT / INTEGRATION 测试放到 `src/` 中（应放到 `tests/` 目录）
- ❌ 用模块名或功能名随意命名（如 `cloud-gateway.test.ts` 对应 `CloudGatewayService.ts`）
- ❌ 驼峰/kebab-case 混用（被测文件是 `UserService.ts`，测试文件不能叫 `user-service.test.ts`）
- ❌ 将不同测试类型混写在同一个测试文件中
- ❌ 不确定命名规范时自行发明，必须先检查现有测试文件的命名模式

## 要求

- 优先行为级别测试
- 优先工作流的集成测试
- 当 API 模式稳定性重要时添加契约测试
- 当存在不变规则时添加属性测试
- 不要修改场景含义
- 不要削弱现有测试

## 测试类型优先级

**contract > integration > property > unit**

## 测试原则

- 测试行为而非内部实现
- 避免与私有辅助函数绑定的脆弱测试
- 确保测试能验证场景中描述的行为
- 保持测试简洁、可读、可维护

## 默认执行模式：一把梭

**当 spec 和 scenario 已存在时，AI 默认连续完成以下全部步骤，不中途停止：**

```
1. 建立 Implementation Stub（若实现文件不存在）
2. 将所有 scenario 实现为可执行的行为测试（全部红）
3. 实现功能代码直到所有测试通过（全部绿）
4. 运行 CI 验证（lint + typecheck + tests）
```

**唯一允许中途停下的情况**：遇到真实阻塞（Spec 歧义、需要人工决策的架构分歧、外部依赖不可用）。此时必须明确说明阻塞原因，而不是以"scaffold 完成"或"stub 已建立"作为交付物。

---

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
