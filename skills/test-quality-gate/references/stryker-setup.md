# Stryker 变异测试配置

## 安装

```bash
pnpm add -D @stryker-mutator/core @stryker-mutator/typescript-checker
```

根据测试框架安装对应 runner：

```bash
# Vitest
pnpm add -D @stryker-mutator/vitest-runner

# Jest
pnpm add -D @stryker-mutator/jest-runner
```

## 配置文件

创建 `stryker.config.json`（推荐 JSON 格式，避免额外的 TS 编译开销）：

### Vitest 项目

```json
{
  "$schema": "https://raw.githubusercontent.com/stryker-mutator/stryker/master/packages/core/schema/stryker-schema.json",
  "testRunner": "vitest",
  "checkers": ["typescript"],
  "tsconfigFile": "tsconfig.json",
  "mutate": [
    "src/**/*.{ts,tsx}",
    "!src/**/*.test.{ts,tsx}",
    "!src/**/*.spec.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/index.{ts,tsx}",
    "!src/**/__tests__/**",
    "!src/**/__mocks__/**",
    "!src/**/*.stories.tsx"
  ],
  "reporters": ["html", "clear-text", "json"],
  "htmlReporter": {
    "fileName": "reports/mutation/index.html"
  },
  "jsonReporter": {
    "fileName": "reports/mutation/mutation.json"
  },
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": 50
  },
  "ignoreStatic": true,
  "incremental": true,
  "incrementalFile": ".stryker-incremental.json"
}
```

### Jest 项目

```json
{
  "$schema": "https://raw.githubusercontent.com/stryker-mutator/stryker/master/packages/core/schema/stryker-schema.json",
  "testRunner": "jest",
  "jest": {
    "configFile": "jest.config.ts"
  },
  "checkers": ["typescript"],
  "tsconfigFile": "tsconfig.json",
  "mutate": [
    "src/**/*.{ts,tsx}",
    "!src/**/*.test.{ts,tsx}",
    "!src/**/*.spec.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/index.{ts,tsx}",
    "!src/**/__tests__/**",
    "!src/**/__mocks__/**",
    "!src/**/*.stories.tsx"
  ],
  "reporters": ["html", "clear-text", "json"],
  "htmlReporter": {
    "fileName": "reports/mutation/index.html"
  },
  "jsonReporter": {
    "fileName": "reports/mutation/mutation.json"
  },
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": 50
  },
  "ignoreStatic": true,
  "incremental": true,
  "incrementalFile": ".stryker-incremental.json"
}
```

## 关键配置说明

### thresholds

```
high: 80   → 变异得分 >= 80% 显示绿色（健康）
low:  60   → 变异得分 >= 60% 显示黄色（警告）
break: 50  → 变异得分 < 50% 则 CI 失败（门禁）
```

`break` 是 CI 门禁阈值。低于此值 Stryker 进程以非零退出码结束，CI 步骤失败。

### ignoreStatic

设为 `true`。静态变异体（如常量声明 `const X = 42`）通常是等价变异体，杀不死但也不代表测试缺失。忽略它们减少噪声。

### incremental

设为 `true`。增量模式只对上次运行以来变更的文件重新跑变异测试。大幅减少 CI 耗时。

需要持久化 `.stryker-incremental.json` 文件（通过 CI cache）。

## package.json scripts

```json
{
  "scripts": {
    "test:mutation": "stryker run",
    "test:mutation:changed": "stryker run --mutate \"$(git diff --name-only origin/${GITHUB_BASE_REF:-main}...HEAD -- 'src/**/*.ts' 'src/**/*.tsx' | grep -E '\\.(ts|tsx)$' | grep -v -E '\\.(test|spec|stories)\\.' | grep -v '__tests__/' | grep -v '__mocks__/' | grep -v '\\.d\\.ts$' | tr '\\n' ',')\""
  }
}
```

**设计说明**：

- 使用两个独立的 git pathspec（`'src/**/*.ts'` 和 `'src/**/*.tsx'`）而非 `{ts,tsx}` brace 语法，因为 git pathspec 和单引号内都不支持 brace expansion
- 在 pipe 中用 `grep -v` 手动排除测试文件、stories、mock 等，因为 `--mutate` CLI 参数会**整体替换**配置文件中的 `mutate` 数组（包括其中的排除规则）
- `GITHUB_BASE_REF` 由 GitHub Actions 在 `pull_request` 事件中自动设置；本地运行时回退到 `main`

## 排除低价值文件

以下文件不适合变异测试，应在 `mutate` 中排除：

| 类别 | Glob | 原因 |
|------|------|------|
| 纯类型 | `**/*.d.ts`, `**/types.ts` | 无运行时逻辑 |
| 配置 | `*.config.*` | 构建配置，非业务逻辑 |
| Barrel | `**/index.ts`（纯 re-export） | 无逻辑可变异 |
| 常量定义 | 视项目而定 | `ignoreStatic` 已覆盖大部分场景 |
| 纯 UI 模板 | `**/*.stories.tsx` | Storybook 文件，非业务逻辑 |

## .gitignore

确保以下目录在 `.gitignore` 中：

```
reports/mutation/
.stryker-tmp/
```

增量文件 `.stryker-incremental.json` 位于项目根目录（不在 `reports/mutation/` 内），**不要** gitignore — CI cache 需要读取它。
