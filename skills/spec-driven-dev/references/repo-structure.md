# 推荐仓库结构

## 单仓结构

```
spec/
  user-service.md                  ← Spec 文件，按功能命名
  user-service.scenarios.md        ← Scenario 文件，与 Spec 同目录

src/
  services/
    UserService.ts
    UserService.test.ts            ← UNIT + PROPERTY，colocate
tests/
  contract/                        ← CONTRACT，子目录镜像 src/
    services/
      UserService.contract.test.ts
  integration/                     ← INTEGRATION，子目录镜像 src/
    services/
      UserService.integration.test.ts
```

## Monorepo 结构

```
spec/
  user-service.md                  ← Spec
  user-service.scenarios.md        ← Scenario

apps/my-app/                    ← workspace
  src/
    services/
      UserService.ts
      UserService.test.ts       ← UNIT + PROPERTY，colocate
  tests/
    contract/                        ← CONTRACT，子目录镜像 src/
      services/
        UserService.contract.test.ts
    integration/                     ← INTEGRATION，子目录镜像 src/
      services/
        UserService.integration.test.ts

libs/my-lib/                    ← 另一个 workspace
  src/
    AuthToken.ts
    AuthToken.test.ts           ← UNIT + PROPERTY，colocate
  tests/
    contract/                        ← CONTRACT，子目录镜像 src/
      AuthToken.contract.test.ts
    integration/                     ← INTEGRATION，子目录镜像 src/
      AuthToken.integration.test.ts
```

## 归属原则

测试先归属 workspace，再按类型分目录。**禁止跨 workspace 在仓库根聚合测试。**

## 测试文件位置规则

| 类型            | 位置                                    |
| --------------- | --------------------------------------- |
| UNIT / PROPERTY | colocate，紧邻被测文件（`src/` 内）     |
| CONTRACT        | `tests/contract/`，子目录镜像 `src/`    |
| INTEGRATION     | `tests/integration/`，子目录镜像 `src/` |

## 测试文件命名规则

**测试文件名 = 被测文件名 + 可选测试类型后缀 + `.test` 或 `.spec`**，大小写和风格必须与被测文件完全一致。

- **UNIT / PROPERTY**（colocate）：`UserService.test.ts`
- **CONTRACT**（tests/contract/）：`UserService.contract.test.ts`
- **INTEGRATION**（tests/integration/）：`UserService.integration.test.ts`

CONTRACT 和 INTEGRATION 测试文件通过 `.contract.` / `.integration.` 后缀区分类型，避免与 colocate 的 UNIT 测试文件名冲突。

**前置步骤**：写测试前，先检查项目里已有的测试文件命名模式（`.test.ts` 还是 `.spec.ts`），与现有模式保持一致。

`__tests__/` 目录仅用于存放测试辅助工具（helpers、fixtures、mocks），不存放测试文件本身。

禁止：
- ❌ 用模块名或功能名随意命名（如 `cloud-gateway.test.ts` 对应 `CloudGatewayService.ts`）
- ❌ 驼峰/kebab-case 混用（被测文件是 `UserService.ts`，测试文件不能叫 `user-service.test.ts`）
- ❌ 将不同测试类型混写在同一个测试文件中
- ❌ 不确定命名规范时自行发明，必须先检查现有测试文件的命名模式

**写完测试后自检：**

1. [monorepo] 测试文件是否在被测代码所属的 workspace 内？
2. 文件里所有 test case 的类型是否一致？（混合则拆分）
3. 文件路径是否与测试类型匹配？

## 测试优先级

见 `scenario-format.md` > 测试类型标记。
