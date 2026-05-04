---
name: code-review
description: "工程级代码审查：脚本检测克隆 + LLM 精筛意图级重复与抽象建议。触发词：review, code review, 代码审查, 重复检测"
metadata:
  version: 0.1.0
  tags: [review, quality, duplication, refactoring]
---

# Code Review

脚本收数据 + LLM 做判断的两阶段代码审查。

**核心问题**：AI 生成的代码容易在多处分别实现同一逻辑（不存在 import 关系，靠引用分析发现不了），且随着迭代逐渐积累抽象缺失、职责混乱等问题。

## 适用场景

- 开发完成后对改动做 review（`--scope=diff`）
- 定期全工程扫描，发现积累的技术债（`--scope=full`）
- 怀疑项目中存在大量重复逻辑，需要量化评估
- 重构前摸底：找出应该抽取的公共模块

## 必须材料

- Node.js 16+（运行 jscpd）
- jscpd：全局安装或通过 npx 自动调用（`npm install -g jscpd` 可选）
- Git 仓库（diff 模式需要）

## 执行步骤

### Phase 1: 脚本收集（确定性）

运行克隆检测脚本：

```bash
# 全工程扫描
bash scripts/detect-clones.sh --scope=full

# 扫描全工程，但只展示涉及当前分支改动文件的克隆
bash scripts/detect-clones.sh --scope=diff --base=main

# 自定义阈值（更宽松，抓更多疑似）
bash scripts/detect-clones.sh --scope=full --min-lines=3 --min-tokens=30
```

脚本输出 JSON 报告到 `.code-review/clones-report.json`。

### Phase 2: LLM 精筛（判断力）

读取 Phase 1 的 JSON 报告，执行以下分析：

1. **确认/排除克隆**
   - 读取报告中的每组克隆
   - 读对应源码，判断是否为真正的重复（排除：测试数据、配置模板、协议约定的重复结构）
   - 对真正的重复标记优先级（按克隆行数 × 出现次数排序）

2. **补漏意图级重复**（jscpd 抓不到的）
   - 以 Phase 1 报告中涉及的文件为起点，扩展到相关模块，按模块分批阅读
   - 重点关注：
     - 同一逻辑不同写法（手写 vs 库调用 vs 模板字符串）
     - 相似的错误处理/重试/校验模式
     - 可以合并的相似函数（参数略有不同）
   - 参考 `references/review-guide.md` 中的检测模式清单

3. **设计质量检查**
   - 若无必要勿增实体：每个新增 prop/参数/配置字段/wrapper 层/抽象层/style override，问"去掉它会 break 什么"
   - 找到底层规则，派生一切：多个值之间有数学/逻辑关系的（UI、配置、领域参数、API 输入均适用），只暴露根变量
   - 参考 `references/review-guide.md` 中的模式 5、6
   - **建模对齐检查**：如果变更涉及领域实体/关系/不变量/派生关系，或对现有实体引入状态变化逻辑（与 `modeling-first` skill 触发条件一致），查找对应的 `model.md`（通常在 `docs/models/` 或 feature 目录）；若存在，确认实现未偏离模型；若不存在但本应存在，记录为 Major 并建议补建模。**注意**：若本次 review 是在 `spec-driven-dev` 流程的 CI 验证阶段（步骤 11.3）中被调用，跳过 ref 存在性验证（upstream coverage gate 已覆盖），但仍执行语义对齐验证（实现是否偏离 `model.md` 声明的实体/关系/不变量语义）

4. **抽象与边界**（模块层面：deep / shallow / seam）

   模式 5/6 检查的是**单值/字段/参数层面**的冗余（一个 prop、一个派生值）。本步骤检查**模块层面**的抽象质量——同一组代码作为一个整体，是 deep 还是 shallow？seam 在挡什么真实变化？这是粒度互补，**不复述模式 5/6**，参考 `references/review-guide.md` 中的"抽象与边界"小节。

   对每个新增/修改的模块（文件、类、函数族、wrapper 层），LLM 顺序回答三个问题：

   - **Q1：这个模块是 deep 还是 shallow？** 接口复杂度 vs 内部复杂度。Deep = 接口窄、内部干很多事（如 Unix 文件 API）；Shallow = 接口和实现一样复杂，本质是 thin wrapper，不藏复杂度只增认知负担
   - **Q2：删掉它，复杂度散到 N 个调用方，还是凭空消失？**（deletion test）散到调用方且每个都做几乎一样的事 → deep，保留；凭空消失，调用方不补任何东西 → shallow，删
   - **Q3：这个 seam 在挡什么真实变化？**（seam justification）说不出真实变化理由 → 抽象债（为"将来可能"造的 seam）；有真实需要变化的理由 → 保留

   标记为 HIGH（shallow wrapper 增加无价值认知负担 / seam 无 justification）或 MEDIUM（接口边界设计可优化）。**与建模对齐检查不冲突**：建模对齐看模型语义偏离，本步骤看模块抽象结构，同一模块两类问题分别报告。

5. **结构性问题扫描**（LLM 在阅读代码时顺带检查，无独立脚本）
   - 文件/函数是否超长（文件 > 300 行，函数 > 50 行）
   - 嵌套是否过深（> 3 层）
   - 是否存在应该提升为共享模块的局部定义（被多文件以不同方式重复实现）

> **Roadmap**: 若 jscpd 对实际项目漏报过多（同一逻辑换变量名/换写法即漏检），考虑引入 AST 归一化比对（ts-morph）或结构化复杂度检测脚本作为 Phase 1 补充。判定标准：在 3 个以上真实项目中，LLM Phase 2 补漏的意图级重复数量持续 > jscpd 检测数量的 2 倍。

### Phase 3: 输出报告与建议

生成结构化 review report，格式见"产物与格式"。

## 产物与格式

### Review Report（输出到 `.code-review/review-report.md`）

```markdown
# Code Review Report

**Scope**: full / diff (vs main)
**Date**: YYYY-MM-DD
**Files scanned**: N

## Summary

| 类别 | 数量 | 严重程度 |
|------|------|----------|
| 文本级克隆 (jscpd) | N 组 | 🔴/🟡/🟢 |
| 意图级重复 (LLM) | N 组 | 🔴/🟡/🟢 |
| 冗余实体 (模式 5) | N 处 | 🔴/🟡 |
| 未派生值 (模式 6) | N 处 | 🔴/🟡 |
| 超长文件/函数 | N 处 | 🟡 |
| 抽象建议 | N 项 | 🟢 |

## Clones (jscpd detected)

### 1. [HIGH] <描述>
- **文件 A**: `path/to/file.ts:10-35`
- **文件 B**: `path/to/other.ts:20-45`
- **克隆行数**: 25
- **建议**: 抽取为 `shared/utils/xxx.ts`，统一引用

## Intent Duplicates (LLM detected)

### 1. [MEDIUM] <描述>
- **位置**: `fileA.ts:fn1`, `fileB.ts:fn2`, `fileC.ts:fn3`
- **模式**: 三处分别实现了日期格式化，写法不同但意图相同
- **建议**: 统一使用 dayjs，抽取 `formatDate()` 到 utils

## Design Quality Issues

### 1. [HIGH] <冗余实体 / 未派生值 描述>
- **位置**: `path/to/component.tsx:ComponentName`
- **规则**: 模式 5（若无必要勿增实体）/ 模式 6（找到底层规则，派生一切）
- **问题**: 具体描述
- **建议**: 具体修复方案

## Structural Issues

### 1. `path/to/large-file.ts` (420 lines)
- **问题**: 超过 300 行限制
- **建议**: 按职责拆分为 X、Y、Z 三个模块

## Action Items (by priority)

- [ ] 🔴 HIGH: ...
- [ ] 🟡 MEDIUM: ...
- [ ] 🟢 LOW: ...
```

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"

### 本 skill 特定检查

- [ ] jscpd 脚本成功运行并产出 JSON 报告
- [ ] 所有 jscpd 标记的克隆经过 LLM 确认/排除，无遗漏
- [ ] 意图级重复的检测覆盖了所有受影响模块
- [ ] 模式 5（冗余实体）和模式 6（未派生值）已检查并在报告中体现
- [ ] 每个问题都有具体的重构建议（不是泛泛的"需要优化"）
- [ ] Action items 按优先级排序，高优先级项有明确的目标文件和方法

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定验证

1. 检查 `.code-review/clones-report.json` 是否生成且非空
2. 检查 `.code-review/review-report.md` 是否覆盖了所有克隆组
3. 抽查 2-3 个"意图级重复"，确认 LLM 判断合理
4. 确认 action items 可直接执行（有文件路径、行号、建议的抽取位置）

## 反模式合集

> 本节用 ✗/✓ 对照列出**使用本 skill 时**容易出错的方式。LLM 对反例敏感度高于正例——单纯说"应该 X"不如说"不要 Y，因为 Z"。

✗ **跳过 Phase 1 直接 LLM 读代码做 review**
为什么错：jscpd 抓的文本级克隆 LLM 边读边数容易漏（尤其是大量小重复）。结构化数据先收集再判断更稳。
✓ 先跑 `detect-clones.sh`，再以 JSON 报告为 LLM 精筛起点。

✗ **建议写成"需要优化" 不带文件路径行号**
为什么错：Action item 不可执行 = 等同没写，下游无法跟进。
✓ 每条带 `path:line` + 具体改动方向（抽到哪个模块、合并到哪个函数、删除哪个 wrapper）。

✗ **所有问题都标 HIGH**
为什么错：没有优先级 = 没有优先级，用户不知道先改哪个，结果一个不改。
✓ 按"修复成本 vs 风险"排，HIGH 控制在 ≤ 3 项；其余分流到 MEDIUM/LOW。

✗ **把 OWASP 漏洞 / 性能瓶颈塞进 review 报告**
为什么错：本 skill 不覆盖这些（见"不覆盖范围"），让用户误以为已覆盖会漏检真正的安全审查。
✓ 发现这类问题，在 Action items 里标记"建议另起 security-review / profiling"，不冒充自己已审。

✗ **审完不写 `review-report.md`，只口头说几条**
为什么错：失去 trail，下次重审无法对照"上次哪些问题没修"。
✓ 始终输出到 `.code-review/review-report.md`，即使只发现 1-2 个问题。

## 不覆盖范围

- 不负责执行重构（只输出建议，人决定改哪些）
- 不做安全审计（OWASP 等由专门工具覆盖）
- 不做性能分析（profiling 不在此 skill 范围）
- 不替代 PR review（此 skill 侧重结构性问题，不审逻辑正确性）

## 覆盖声明

无

## 引用资料

- `scripts/detect-clones.sh` — jscpd 包装脚本
- `references/review-guide.md` — LLM 精筛与重构建议指引
