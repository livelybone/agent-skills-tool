# 覆盖率配置

## 框架检测与配置

### Vitest

检测标志：`vitest.config.ts` 或 `package.json` 中 `devDependencies` 含 `vitest`。

在 `vitest.config.ts` 中添加 coverage 配置：

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    coverage: {
      provider: "v8", // 推荐；备选 "istanbul"
      reporter: ["text", "json-summary", "html"],
      reportsDirectory: "./coverage",
      include: ["src/**/*.{ts,tsx}"],
      exclude: [
        "src/**/*.test.{ts,tsx}",
        "src/**/*.spec.{ts,tsx}",
        "src/**/*.d.ts",
        "src/**/index.ts", // barrel files
        "src/**/__tests__/**",
        "src/**/__mocks__/**",
        "src/**/types.ts",
      ],
      thresholds: {
        // 见 thresholds.md 获取推荐值
        statements: 80,
        branches: 75,
        functions: 80,
        lines: 80,
      },
    },
  },
});
```

安装依赖：

```bash
pnpm add -D @vitest/coverage-v8
```

在 `package.json` 中添加 script：

```json
{
  "scripts": {
    "test:coverage": "vitest run --coverage"
  }
}
```

### Jest

检测标志：`jest.config.ts`/`jest.config.js` 或 `package.json` 中 `devDependencies` 含 `jest`。

在 `jest.config.ts` 中添加 coverage 配置：

```ts
import type { Config } from "jest";

const config: Config = {
  collectCoverage: true,
  coverageProvider: "v8",
  coverageReporters: ["text", "json-summary", "html"],
  coverageDirectory: "./coverage",
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.test.{ts,tsx}",
    "!src/**/*.spec.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/index.ts",
    "!src/**/__tests__/**",
    "!src/**/__mocks__/**",
  ],
  coverageThreshold: {
    global: {
      statements: 80,
      branches: 75,
      functions: 80,
      lines: 80,
    },
  },
};

export default config;
```

在 `package.json` 中添加 script：

```json
{
  "scripts": {
    "test:coverage": "jest --coverage"
  }
}
```

## 排除规则

以下文件默认排除出覆盖率统计（不贡献覆盖率，也不拉低覆盖率）：

| 类别 | Glob 模式 | 原因 |
|------|----------|------|
| 测试文件 | `**/*.test.{ts,tsx}`, `**/*.spec.{ts,tsx}` | 测试自身不需要被覆盖 |
| 类型声明 | `**/*.d.ts` | 无运行时代码 |
| Barrel 导出 | `**/index.ts`（仅含 re-export 的） | 纯转发，无逻辑 |
| 测试辅助 | `**/__tests__/**`, `**/__mocks__/**` | 测试基础设施 |
| 配置文件 | `*.config.ts`, `*.config.js` | 构建/工具配置 |
| 纯类型文件 | `**/types.ts`, `**/types/**` | 无运行时代码 |

**注意**：排除列表应根据项目实际情况调整。检查现有配置中是否已有排除规则，合并而非覆盖。

## .gitignore

确保 `coverage/` 目录在 `.gitignore` 中：

```
coverage/
```
