# CI 工作流模板

## GitHub Actions

### 检测现有 CI

检查 `.github/workflows/` 下的 YAML 文件：

1. 是否已有测试步骤（搜索 `pnpm test`、`vitest`、`jest`）
2. 是否已有覆盖率步骤（搜索 `--coverage`、`coverage`）
3. 是否已有变异测试步骤（搜索 `stryker`、`mutation`）

**已有测试 CI** → 在现有工作流中追加覆盖率和变异测试步骤
**无 CI** → 使用下方完整模板创建新工作流

### 追加策略（已有 CI）

在现有测试工作流中，找到测试步骤后追加。

**前提**：确认现有工作流的 `actions/checkout` 步骤使用 `fetch-depth: 0`（完整历史）。如果当前是默认的浅克隆（`fetch-depth: 1`），必须改为 `fetch-depth: 0`，否则 `git diff origin/$BASE_REF...HEAD` 无法正常工作。

```yaml
      # 追加在现有 test 步骤之后
      - name: Coverage check
        run: pnpm test:coverage

      - name: Upload coverage report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/

      - name: Restore Stryker incremental cache
        if: github.event_name == 'pull_request'
        uses: actions/cache@v4
        with:
          path: .stryker-incremental.json
          key: stryker-incremental-${{ github.base_ref }}-${{ hashFiles('src/**/*.ts', 'src/**/*.tsx') }}
          restore-keys: |
            stryker-incremental-${{ github.base_ref }}-
            stryker-incremental-

      - name: Mutation testing (changed files)
        if: github.event_name == 'pull_request'
        run: pnpm test:mutation:changed
        env:
          GITHUB_BASE_REF: ${{ github.base_ref }}

      - name: Upload mutation report
        if: always() && github.event_name == 'pull_request'
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: reports/mutation/
```

### 完整模板（新建 CI）

创建 `.github/workflows/test-quality.yml`：

```yaml
name: Test Quality Gate

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: test-quality-${{ github.ref }}
  cancel-in-progress: true

jobs:
  coverage:
    name: Coverage
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".node-version"
          cache: "pnpm"

      - run: pnpm install --frozen-lockfile

      - name: Run tests with coverage
        run: pnpm test:coverage

      - name: Upload coverage report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/

  mutation:
    name: Mutation Testing
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # 完整历史，用于 git diff origin/$BASE_REF...HEAD

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".node-version"
          cache: "pnpm"

      - run: pnpm install --frozen-lockfile

      - name: Restore Stryker incremental cache
        uses: actions/cache@v4
        with:
          path: .stryker-incremental.json
          key: stryker-incremental-${{ github.base_ref }}-${{ hashFiles('src/**/*.ts', 'src/**/*.tsx') }}
          restore-keys: |
            stryker-incremental-${{ github.base_ref }}-
            stryker-incremental-

      - name: Run mutation testing (changed files)
        run: pnpm test:mutation:changed
        env:
          GITHUB_BASE_REF: ${{ github.base_ref }}

      - name: Upload mutation report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: reports/mutation/
```

## 适配要点

使用模板前，必须根据项目实际情况调整：

| 项 | 检查 | 调整 |
|----|------|------|
| Node 版本 | `.node-version`、`.nvmrc`、`package.json engines` | 替换 `node-version-file` 或改用 `node-version: "20"` |
| pnpm 版本 | `package.json packageManager` | `pnpm/action-setup@v4` 自动读取；若无则需指定 `version` |
| Monorepo | 是否有 workspace | 可能需要 `working-directory` 或 `--filter` |
| 现有 CI | `.github/workflows/` | 优先追加步骤，而非新建工作流 |
| 分支名 | `main` / `master` / 其他 | 根据项目实际默认分支调整 |

## Monorepo 适配

对 pnpm workspace monorepo，覆盖率和变异测试应按 package 粒度运行：

```yaml
      - name: Coverage (affected packages)
        run: pnpm --filter "...[origin/${GITHUB_BASE_REF:-main}]" test:coverage

      - name: Mutation testing (affected packages)
        run: pnpm --filter "...[origin/${GITHUB_BASE_REF:-main}]" test:mutation:changed
        env:
          GITHUB_BASE_REF: ${{ github.base_ref }}
```

前提：每个 package 的 `package.json` 都有 `test:coverage` 和 `test:mutation:changed` 脚本。
