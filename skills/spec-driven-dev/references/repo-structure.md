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
      services/
        AuthToken.contract.test.ts
    integration/                     ← INTEGRATION，子目录镜像 src/
      services/
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

## 测试优先级

见 `scenario-format.md` > 测试类型标记。
