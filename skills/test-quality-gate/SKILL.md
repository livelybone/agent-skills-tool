---
name: test-quality-gate
description: "为 TypeScript 项目配置测试覆盖率和变异测试的 CI 质量门禁。检测项目现有配置，补全缺失的覆盖率报告（Vitest/Jest + v8/Istanbul）和变异测试（Stryker），生成 GitHub Actions 工作流，CI 不通过时提供修复指引。触发词：coverage、mutation testing、test quality、质量门禁、覆盖率、变异测试、Stryker。"
metadata:
  version: 1.0
  tags:
    - testing
    - ci
    - coverage
    - mutation-testing
    - typescript
---

# Test Quality Gate

为 TypeScript 项目配置测试覆盖率 + 变异测试的 CI 质量门禁。

## 核心理念

- **覆盖率是下限门槛，不是目标** — 防止覆盖率滑坡，但高覆盖率不等于高质量
- **变异测试量化测试有效性** — 测试是否真的在保护行为，而非只是执行代码
- **增量优先** — 只对变更文件跑变异测试，避免全量跑导致 CI 过慢

## 前置条件

- TypeScript 项目
- 测试框架：Vitest 或 Jest（自动检测）
- 包管理器：pnpm（遵循全局偏好）
- CI 平台：GitHub Actions

## 执行流程

### 1. 检测现有配置

按顺序检查以下项目，输出检测报告：

| 检测项 | 检查位置 | 状态 |
|--------|---------|------|
| 测试框架 | `package.json` dependencies、`vitest.config.*`、`jest.config.*` | Vitest / Jest / 未检测到 |
| 覆盖率配置 | 测试框架配置文件中的 `coverage` 字段 | 已配置 / 未配置 |
| 覆盖率阈值 | `coverage.thresholds` 或 `coverageThreshold` | 已设置 / 未设置 |
| Stryker 配置 | `stryker.config.*`、`package.json` 中的 `@stryker-mutator/*` | 已配置 / 未配置 |
| CI 工作流 | `.github/workflows/*.yml` 中是否包含 coverage/mutation 步骤 | 已有 / 缺失 |
| 覆盖率 CI 门禁 | CI 中是否有覆盖率检查步骤且配置了失败条件 | 已有 / 缺失 |
| 变异测试 CI 门禁 | CI 中是否有 Stryker 步骤且配置了阈值 | 已有 / 缺失 |

### 2. 补全缺失配置

根据检测结果，**只补全缺失项**，不修改已有配置：

**缺覆盖率配置** → 见 `references/coverage-setup.md`
**缺 Stryker** → 见 `references/stryker-setup.md`
**缺 CI 工作流** → 见 `references/ci-templates.md`

### 3. 阈值配置

默认阈值见 `references/thresholds.md`。

配置阈值时必须考虑项目现状：

- **新项目**（覆盖率 < 30%）：从当前值 - 5% 起步（留缓冲），逐步提升
- **成熟项目**（覆盖率 > 60%）：直接使用推荐阈值
- **已有阈值**：不降低现有标准

### 4. 验证

配置完成后，本地运行验证：

```bash
# 覆盖率
pnpm test:coverage

# 变异测试（全量）
pnpm test:mutation
```

确认两项都能正常执行并输出报告。

---

## CI 不通过时的修复指引

当 CI 质量门禁失败时，按以下决策树定位问题并修复：

### 覆盖率不达标

```
覆盖率低于阈值
├─ 是新增代码未覆盖？
│  └─ 为新增代码补充测试（优先 [CRITICAL] 场景）
├─ 是删除测试导致？
│  └─ 确认删除合理性；若合理，调整阈值（需人工确认）
└─ 是阈值不合理？
   └─ 提议调整，说明理由（需人工确认）
```

**修复原则**：
- 补测试时遵循 `testing-guide.md`：优先契约稳定性、主要业务流程、关键业务规则
- **禁止为凑覆盖率写无价值测试**（getter/setter、琐碎逻辑、实现细节）
- 如果正当代码变更导致覆盖率微降（< 2%），可提议调整阈值而非强行补测试

### 变异测试不达标

```
变异得分低于阈值
├─ 存活变异体在关键业务逻辑中？
│  └─ 补充针对性测试（断言该行为的输入→输出契约）
├─ 存活变异体在边界条件中？
│  └─ 补充边界测试
├─ 存活变异体在琐碎代码中？
│  └─ 考虑将该文件/函数排除出变异测试范围（见 thresholds.md）
└─ 等价变异体（改了代码但行为不变）？
   └─ 无需处理，Stryker 的 `--ignoreStatic` 可减少此类噪声
```

**修复原则**：
- 优先杀死关键业务逻辑中的存活变异体
- 琐碎代码（日志、格式化、纯展示）中的存活变异体可以忽略
- 通过 Stryker 的 `mutate` 配置排除低价值文件，而非写低价值测试

---

## Over-testing 的 CI 可量化映射

用户的核心关切"避免过度测试"在 `spec-driven-dev/testing-guide.md` 中被定义为 5 类。CI 层面**不能全部量化**——本 skill 与 spec-driven-dev 的审查环节互补：

| Over-testing 类型 | CI 层面可捕获 | 捕获机制 | 仍需人工/AI 审查 |
|-------------------|--------------|---------|-----------------|
| 私有辅助函数测试 | ❌ 否 | — | ✅ scenario/test review |
| 实现细节耦合 | ⚠️ 间接 | **高覆盖率 + 低变异得分**是强信号；变异测试能暴露"断言路过而非验证" | ✅ test review 仍需检查断言形态 |
| 琐碎逻辑测试 | ⚠️ 部分 | 通过 coverage `exclude` 和 Stryker `mutate` 排除规则隐式处理 | ✅ scenario review 环节删除 |
| 脆弱快照 | ⚠️ 间接 | 可通过 CI 中增加 snapshot 文件数量/体积监控（本 skill 未内置） | ✅ test review 检测 `toMatchSnapshot` 滥用 |
| 重复案例 | ❌ 否 | — | ✅ scenario/test review |

**关键判断**：装了本 skill 的 CI **不等于**解决了过度测试。CI 只解决"测试是否有效保护行为"（变异测试）和"覆盖率是否下滑"（coverage gate）。过度测试的识别与删除仍必须依赖 `spec-driven-dev` 中的 scenario/test review 环节。

不要把 CI 通过误读为"测试质量合格"——它只说明"没有明显的覆盖不足和断言失效"。

---

## 与 spec-driven-dev 的双向接线

本 skill 与 `spec-driven-dev` 是**双向引用**关系：

**spec-driven-dev → test-quality-gate**（定义的要求）：

- `spec-driven-dev/references/workflow-standard.md` 步骤 6.2 已将 **coverage gate** 和 **mutation score gate** 列为 CI 最低检查
- `spec-driven-dev/SKILL.md` 的 DoD 已将这两项列入"CI 验证通过"的必要条件
- 当 spec-driven-dev 执行到 CI Verification 时，如项目尚未配置这两项，应触发本 skill 的配置补全流程

**test-quality-gate → spec-driven-dev**（共享的原则）：

- `testing-guide.md` 定义的"测什么/不测什么"是本 skill 配置阈值和排除规则的依据
- CI 打回时的修复优先级遵循 `testing-guide.md`（契约稳定性 > 主流程 > 业务规则 > 边界 > 不变量）
- 过度测试的 5 类识别由 spec-driven-dev 的 scenario/test review 承担，本 skill 不重复造轮子（见上方"Over-testing 的 CI 可量化映射"）

---

## Branch Protection（阻止合并）

CI 失败本身**不等于**阻止合并。要让"打回修复"真正落地，必须在 GitHub 仓库配置 branch protection 规则：

1. 进入仓库 **Settings → Branches → Branch protection rules**
2. 对主分支（如 `main`）启用以下规则：
   - ✅ **Require a pull request before merging**
   - ✅ **Require status checks to pass before merging**
     - 在 required status checks 列表中勾选：
       - `Coverage`（来自 `test-quality.yml` 的 coverage job）
       - `Mutation Testing`（来自 `test-quality.yml` 的 mutation job）
   - ✅ **Require branches to be up to date before merging**（可选但推荐）
3. 对管理员也强制执行规则（启用 **Do not allow bypassing the above settings**）

**状态流转**：

```
PR 提交 → CI 运行 → coverage/mutation gate 失败
       → PR 页面显示红色 ❌ 状态
       → "Merge" 按钮被禁用
       → 作者按 SKILL.md 中"CI 不通过时的修复指引"决策树修复
       → push 新 commit → CI 重跑 → 通过后方可合并
```

> 不配置 branch protection，CI 失败只是警告，"打回修复"无强制力。这一步是本 skill 从"工具"升级为"门禁"的关键。

---

## 参考文档索引

| 文档 | 何时读取 |
|------|---------|
| [references/coverage-setup.md](./references/coverage-setup.md) | 配置覆盖率时 |
| [references/stryker-setup.md](./references/stryker-setup.md) | 配置 Stryker 变异测试时 |
| [references/ci-templates.md](./references/ci-templates.md) | 创建或修改 CI 工作流时 |
| [references/thresholds.md](./references/thresholds.md) | 设定或调整阈值时 |
