# 阈值标准与调优

## 推荐阈值

### 覆盖率

| 指标 | 推荐值 | 说明 |
|------|--------|------|
| statements | 80% | 语句覆盖率 |
| branches | 75% | 分支覆盖率（通常最难达标） |
| functions | 80% | 函数覆盖率 |
| lines | 80% | 行覆盖率 |

### 变异测试（Stryker）

| 指标 | 推荐值 | 说明 |
|------|--------|------|
| break | 50% | CI 门禁：低于此值则失败 |
| low | 60% | 警告线：低于此值报告显示黄色 |
| high | 80% | 健康线：高于此值报告显示绿色 |

## 新项目的渐进策略

新项目或覆盖率基线低的项目，不应直接套用推荐值。采用渐进策略：

### 第一步：测量基线

```bash
pnpm test:coverage  # 查看当前覆盖率
pnpm test:mutation   # 查看当前变异得分
```

### 第二步：设定起步阈值

```
起步阈值 = 当前值 - 5%（向下取整到 5 的倍数）
```

示例：当前行覆盖率 47% → 起步阈值 40%。

这样设计是为了：
- 立即建立门禁，防止继续下滑
- 给现有代码留出缓冲，不因历史债务阻塞所有 PR

### 第三步：逐步提升

每个迭代周期（如每两周）评估一次：

- 当前覆盖率已稳定高于阈值 10% → 提升阈值 5%
- 重复直到达到推荐值

在 PR 中调整阈值时，commit message 中说明理由。

## 按目录差异化阈值

不同目录的代码价值不同，可设置差异化阈值：

### Vitest

Vitest 支持按 glob pattern 设置差异化阈值：

```ts
coverage: {
  thresholds: {
    statements: 80,
    branches: 75,
    functions: 80,
    lines: 80,
    // 按 glob pattern 覆盖
    "src/domain/**": {
      statements: 90,
      branches: 85,
      functions: 90,
      lines: 90,
    },
    "src/utils/**": {
      statements: 70,
      branches: 60,
      functions: 70,
      lines: 70,
    },
  },
},
```

### Jest

Jest 支持目录级阈值：

```ts
coverageThreshold: {
  global: {
    statements: 80,
    branches: 75,
    functions: 80,
    lines: 80,
  },
  // 核心业务逻辑：更严格
  "./src/domain/": {
    statements: 90,
    branches: 85,
    functions: 90,
    lines: 90,
  },
  // 工具函数：可适当放宽
  "./src/utils/": {
    statements: 70,
    branches: 60,
    functions: 70,
    lines: 70,
  },
},
```

### Stryker

Stryker 不支持目录级 `break` 阈值，但可通过多次运行实现：

```json
// stryker.config.critical.json — 核心模块，高阈值
{
  "mutate": ["src/domain/**/*.ts"],
  "thresholds": { "break": 70 }
}

// stryker.config.json — 全局，标准阈值
{
  "mutate": ["src/**/*.ts", "!src/domain/**/*.ts"],
  "thresholds": { "break": 50 }
}
```

对应 CI 中跑两次：

```yaml
      - name: Mutation testing (critical modules)
        run: pnpm stryker run stryker.config.critical.json

      - name: Mutation testing (general)
        run: pnpm stryker run
```

## 阈值调整需要人工确认的场景

以下调整**禁止 AI 自行执行**，必须升级给用户：

- **降低任何阈值**：可能是合理的（如大规模重构后），但必须说明理由
- **排除新目录**：可能是合理的（如纯配置目录），但需确认不是在逃避覆盖
- **关闭变异测试的 `break`**：等于取消门禁，必须有明确理由

## 覆盖率与变异得分的关系

| 覆盖率 | 变异得分 | 解读 |
|--------|---------|------|
| 高 | 高 | 理想状态：代码被充分执行且行为被有效验证 |
| 高 | 低 | **危险信号**：代码被执行但断言薄弱，测试在"路过"而非"验证" |
| 低 | 高 | 少量测试但每个都很有效；优先扩大覆盖范围 |
| 低 | 低 | 测试严重不足，需系统性补充 |

**高覆盖率 + 低变异得分**是最需要警惕的情况 — 它制造了虚假的安全感。这正是变异测试存在的价值。
