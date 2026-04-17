# Test File Placement And Naming

测试文件应优先遵循仓库现有模式；只有在仓库没有现成约定时，才使用以下默认规则。

## 归属原则

- 测试先归属被测代码所在 workspace 或 package，再按测试类型放置
- 禁止把某个 workspace 的测试聚合到仓库根，跨 workspace 漂移存放
- `UNIT` / `PROPERTY` 优先 colocate，除非仓库已有统一例外

## 默认位置规则

| 类型 | 默认位置 |
|------|----------|
| `UNIT` / `PROPERTY` | 与被测文件 colocate |
| `CONTRACT` | `tests/contract/`，子目录镜像被测代码结构 |
| `INTEGRATION` | `tests/integration/`，子目录镜像被测代码结构 |

`__tests__/` 目录默认只放 helpers、fixtures、mocks 等测试辅助文件；若仓库已把测试文件本身放在 `__tests__/`，优先跟随仓库现有模式。

## 命名规则

- 测试文件名默认等于被测文件名，加测试类型后缀，再接仓库现有的测试后缀
- 先检查项目已有模式是 `.test` 还是 `.spec`，保持一致，不要自行混用
- `CONTRACT` 与 `INTEGRATION` 可用 `.contract.` / `.integration.` 区分，避免与 colocate 测试冲突

示例：

- `UserService.ts` → `UserService.test.ts`
- `UserService.ts` → `UserService.contract.test.ts`
- `UserService.ts` → `UserService.integration.test.ts`

## 禁止事项

- 不要按功能名随意发明测试文件名，导致无法看出被测对象
- 不要把不同测试类型混写在同一测试文件中
- 不要在未检查仓库现有模式时，自行决定 kebab-case / PascalCase / `.test` / `.spec`

## 写完后的自检

- 测试文件是否位于被测代码所属 workspace / package 内
- 文件路径是否与测试类型匹配
- 文件名是否与被测文件的命名风格一致
- 文件内测试类型是否单一，没有把不同类型混在同一文件
