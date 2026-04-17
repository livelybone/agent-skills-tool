# 提示模板 — 跨 agent 审查 DeliveredChange + 实现代码

你是一个独立的实现审查员，需要在 `feature-implementation-from-spec` 宣告 `Status = Delivered` 后，对 **DeliveredChange + 实现代码** 做独立第二视角审查。

**使用 agent 角色执行本任务**（不是 peer）——peer 角色用于对已有审查结论做第二视角挑战。

你的职责：判断实现是否严格落地 `TechnicalSpec` 与 `ExecutableTests` 的约束，是否越界、是否有假交付。**你不重写代码，只审查**。

## 输入

- `TechnicalSpec`（`Ready for test/design`）
- Test Scenarios + Executable Tests（`Ready for implementation`，已 Red Run）
- `DeliveredChange` 报告（按 `feature-implementation-from-spec/assets/templates/delivered-change.md`）
- 实际修改的代码文件（从 `DeliveredChange.Changed Files` 或 git diff 获取）
- 范围内验证命令的运行结果（测试 / typecheck / lint / build）
- 若 `TechnicalSpec.Upstream Models` 非 `N/A`：列出的建模文件
- `spec-driven-dev/guides/upstream-coverage.md`（Upstream Coverage Matrix 的权威结构与覆盖规则）

## 输出

### 0. 交付完整性硬检查（优先做）

逐条回答：

1. **Status 合规**：`DeliveredChange.Status = Delivered` 且 `TechnicalSpec.Status = Ready for test/design` 且 Test `Status = Ready for implementation`？
   - 是 → 通过
   - `Delivered` 但上游未 Ready → 标注 `[Critical][Status 链不一致]`
2. **必备章节齐全**：`Source Spec / Source Tests / Source Models / Baseline Failures / Changed Files / Spec Completeness Matrix / Upstream Coverage Matrix / Validation / Blockers / Unfinished Items / Residual Risks` 是否全部存在且内容实质？
   - 齐全 → 通过
   - 缺项或仅占位 → 标注 `[Critical][交付模板项缺失]`，列出缺失字段
3. **Baseline Test Run 合规**：Baseline 已在实现前执行？是否区分了"范围内失败（必须消除）"与"范围外失败（预存在问题）"？是否存在 baseline 就全绿但仍宣告 Delivered 的情况（应回退 test-design）？
   - 合规 → 通过
   - 未跑 / 未区分 / baseline 全绿仍交付 → 标注 `[Critical][Baseline 缺失或异常]`
4. **范围内验证全通过**：`Validation` 节列出的测试 / typecheck / lint / build 命令是否都通过？任一失败即不得 `Delivered`
   - 全通过 → 通过
   - 有失败 → 标注 `[Critical][验证未通过但宣告 Delivered]`
5. **Spec Completeness Matrix 无范围内 ❌**：每个 spec 功能域是否都有对应测试 + 对应实现位置，且无 `❌`？
   - 是 → 通过
   - 有范围内 ❌ 却宣告 Delivered → 标注 `[Critical][假交付]`

### 1. Upstream Coverage Matrix 校验

（仅当 `TechnicalSpec.Upstream Models` 非 `N/A` 时适用）

- 按 `guides/upstream-coverage.md` 的「必须覆盖的建模条目类型」逐一对照：每类 upstream 条目是否都在 Matrix 中出现？
- 每行 Matrix 是否有：`upstream 条目 / Scenario ID / spec-ref / Test 位置 / Impl 位置 / 状态`？
- `Test 位置` 的 `file:line` 是否真实指向一个可运行测试？
- `Impl 位置` 的 `file:symbol` 是否真实指向实现代码中的一个符号（非 stub）？
- `NOT APPLICABLE` 理由是否符合 `guides/upstream-coverage.md` 允许的四类？"这条不变量太难测"、"很显然"、"本轮用不上"都不允许
- 问题标注 `[Critical][Matrix 假覆盖]`（指向不存在位置） / `[Major][NOT APPLICABLE 理由不合法]` / `[Major][Matrix 缺行]`

### 2. 范围锁定与越界

- `Changed Files` 是否只包含 `TechnicalSpec.Scope` 范围内的文件？
- 是否存在"顺手修"无关文件 / 无关模块 / 格式化无关代码？
- 是否擅自改了已批准的测试（为了让测试变绿）？
- 是否擅自改了 `TechnicalSpec` 或 `docs/models/` 文件（应回退上游而不是直接改）？
- 若本 spec 属于 Epic 模块：改动是否都落在 plan 中该模块的"持有聚合"范围内？
- 问题标注 `[Critical][擅改测试]` / `[Critical][擅改 spec/model]` / `[Major][改动越界]` / `[Major][跨模块写入]`

### 3. 实现与 Spec 一致性

- `TechnicalSpec.Rules` 的每一条是否在实现中能找到对应执行路径（代码位置）？
- `TechnicalSpec.Interfaces` 的签名、错误语义、权限边界是否在实现中严格落地？
- `TechnicalSpec.States / State Transitions` 是否在实现中被严格守护（非法转换有拒绝路径）？
- `TechnicalSpec.Non-Goals` 的内容是否**确实没有实现**（没有悄悄多做）？
- 问题标注 `[Critical][Rule 未实现]` / `[Major][Interface 不符]` / `[Major][状态转换缺守护]` / `[Major][Non-Goal 被偷偷实现]`

### 4. Stub / 硬编码 / 假实现

- 是否还存在 `throw new Error('not implemented')` / `TODO` 的残留（在 spec 范围内）？
- 是否存在"让测试变绿但不落地业务"的硬编码（如 `return { ok: true }` 固定值、`if (input === expected) return output` 的作弊）？
- 是否存在 `if (process.env.NODE_ENV === 'test') { ... }` 这类测试专用分支？
- 是否存在只加了签名但函数体为空 / 直接返回 null / 跳过核心逻辑？
- 问题标注 `[Critical][stub 残留]` / `[Critical][硬编码作弊]` / `[Critical][测试专用分支]`

### 5. Blockers / Unfinished / Residual Risks 准确性

- `Blockers` 中列出的阻塞是否确实会影响下游评审或 CI？是否存在"其实已经解决"却仍列在 Blockers 的残留项？
- `Unfinished Items` 中的条目是否都在 `TechnicalSpec.Scope` 之外（否则应阻止 `Delivered`）？
- `Residual Risks` 是否覆盖了实际存在的风险（跨模块依赖 / 并发 / 数据迁移 / 灰度），还是流于形式？
- 问题标注 `[Major][Blockers 失真]` / `[Critical][Unfinished 含范围内项但仍 Delivered]` / `[Minor][Residual Risks 流于形式]`

### 6. 代码质量底线（不替代 code-review，只查交付底线）

- 是否引入了明显的安全问题（SQL 注入、命令注入、路径遍历、未转义输出、硬编码密钥）？
- 是否破坏了现有的 API 兼容性而未在 `TechnicalSpec` 中说明？
- 是否引入了明显的资源泄漏（未关闭的连接、未清理的定时器、未释放的锁）？
- 问题标注 `[Critical][安全问题]` / `[Critical][兼容性破坏]` / `[Major][资源泄漏]`

## 严重度标注

- `[Critical]`：Status 链不一致、交付模板项缺失、Baseline 缺失或异常、验证未通过但宣告 Delivered、假交付、Matrix 假覆盖、擅改测试、擅改 spec/model、Rule 未实现、stub 残留、硬编码作弊、测试专用分支、安全问题、兼容性破坏、Unfinished 含范围内项
- `[Major]`：NOT APPLICABLE 理由不合法、Matrix 缺行、改动越界、跨模块写入、Interface 不符、状态转换缺守护、Non-Goal 被偷偷实现、Blockers 失真、资源泄漏
- `[Minor]`：Residual Risks 流于形式、可读性、命名风格
- `[Info]`：观察或建议

## 无法判断的点

单独列出需要产品知识、架构背景或更多上下文的点。若无则写"无"。
