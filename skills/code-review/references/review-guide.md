# Review Guide — LLM 精筛与重构建议指引

## Phase 2 精筛规则

### 克隆确认/排除

jscpd 报告的克隆需要人工判断，以下情况应**排除**（不算真正重复）：

| 场景 | 原因 |
|------|------|
| 测试文件中的重复 setup/fixture | 测试间保持独立比 DRY 更重要 |
| 配置文件的重复结构 | 如 `.eslintrc`、`tsconfig.json`，是协议要求 |
| 接口/类型声明的相似字段 | 不同实体恰好有相似属性，不是重复 |
| import 语句的重复 | 正常依赖引用 |
| 不同模块的 CRUD boilerplate | 如果有 code-gen 在维护，不需要抽取 |

以下情况应**确认**为需要处理的重复：

| 场景 | 严重程度 |
|------|----------|
| 工具函数在多处重新定义（如 `formatDate`、`retry`、`debounce`） | HIGH |
| 错误处理逻辑在多个 API handler 中重复 | HIGH |
| 数据转换/映射逻辑在多处手写 | MEDIUM |
| 相似的表单验证规则分散在各组件中 | MEDIUM |
| 相似的 CSS/样式代码块 | LOW |

### 意图级重复检测模式

jscpd 抓不到的重复类型，需要 LLM 主动扫描：

**模式 1: 同功能不同实现**
```
同一件事出现了 2+ 种写法：
- A 处手写循环，B 处用 lodash，C 处用原生 Array 方法
- 都在做"从数组中按条件筛选并转换"
→ 统一为一种方式，或抽取带参数的公共函数
```

**模式 2: 散落的特化版本**
```
多个函数签名相似、逻辑 80% 相同，仅个别参数/分支不同：
- getUserById, getOrderById, getProductById
- 都是 fetch → validate → transform → cache
→ 抽取泛型函数 getEntityById<T>，或用策略模式
```

**模式 3: 隐式协议**
```
多处代码依赖同一个未声明的约定：
- 都假设日期格式是 "YYYY-MM-DD"
- 都假设 API 返回 { data, error } 结构
- 都硬编码了相同的 magic number
→ 提取为常量/类型/schema，让约定显式化
```

**模式 4: 渐进积累的 God Object**
```
一个文件/类随时间不断膨胀：
- 开始是简单的 utils.ts，现在 500+ 行
- 包含不相关的功能（日期、字符串、网络、DOM）
→ 按领域拆分为独立模块
```

### 设计质量检测模式

以下两条是 AI 生成代码的高频设计缺陷，LLM 审查时必须主动检查。

**模式 5: 若无必要勿增实体**

对每个新增的 prop、参数、配置字段、wrapper 组件、抽象层，问一个问题：**去掉它会 break 什么？** 说不出来就不该加。

典型违规信号：
```
- 组件接受 style override props（如 borderRadius、paddingVertical），但这些值
  从未被消费方覆盖过，或者所有消费方都传同一个值
- 函数参数带默认值，且所有调用点都没传过这个参数
- 中间层组件只是 1:1 透传 props 给子组件，没有附加逻辑
- 定义了 interface/type 但只有一个实现，且没有多态需求
- 暴露了 onXxx 回调 prop 但组件内部完全能自己处理这个逻辑
```

审查动作：
- 对新增的每个 prop/参数，检查调用点是否真的传了不同的值
- 对新增的 wrapper/抽象层，检查它相比直接使用底层 API 多提供了什么
- 标记为 MEDIUM（冗余 prop/参数）或 HIGH（冗余抽象层增加了理解成本）

**模式 6: 找到底层规则，派生一切**

一个系统里大部分值不是独立的，它们之间存在数学或逻辑关系。如果多个值可以从一个根变量推导出来，就不应该让调用方分别输入。这不只适用于 UI——配置、领域参数、API 输入同样适用。

典型违规信号：
```
UI 层：
- height = 40, borderRadius = 20 → borderRadius 应该是 height / 2，不是独立变量
- containerHeight = 48, innerHeight = 40, padding = 4
  → innerHeight = containerHeight - padding * 2，不需要三个独立 prop
- fontSize = 14, lineHeight = 20 → lineHeight = fontSize * 1.43
  → 只需要暴露 fontSize 或 size 等级，lineHeight 是派生值
- 组件同时接受 width、height、aspectRatio，但只需要任意两个

配置/领域层：
- timeout = retryCount * baseDelay → 只需暴露 retryCount 和 baseDelay
- totalPrice = unitPrice * quantity → totalPrice 是派生值，不应作为独立输入
- pageCount = Math.ceil(totalItems / pageSize) → 不需要同时接受三个参数
- endDate = startDate + duration → 只需要两个，第三个是派生的
```

审查动作：
- 对所有接受多个数值/配置参数的函数/组件，检查参数间是否存在可推导关系
- 对 style token / design token，检查是否有值是另一个值的函数
- 对配置对象，检查是否有字段可以从其他字段计算得出
- 找到根变量后，建议将派生值改为内部计算，只暴露根变量
- 标记为 HIGH（多个应该联动的值被当作独立输入，改一个漏另一个会导致 bug）

> **辅助检测提示**：若项目使用 TypeScript，建议配置 ESLint `no-unused-vars` 和 `@typescript-eslint/no-unnecessary-type-parameters` 等规则，可自动捕获部分"声明了但未使用"的冗余实体（模式 5 的子集）。

## Phase 3 重构建议规则

### 抽取位置决策

```
被引用 ≥ 2 处 且 在同一模块内 → 模块内 utils（如 components/shared/）
被引用 ≥ 2 处 且 跨模块       → 项目级 shared/utils/
被引用 ≥ 2 处 且 跨项目（monorepo）→ packages/shared/
仅 1 处引用但逻辑独立可测    → 就地保留，不强制抽取
```

### 命名建议规则

- 抽取的函数/模块名应反映**意图**而非实现（`retryWithBackoff` 而非 `loopAndWait`）
- 文件名反映模块职责（`date-formatter.ts` 而非 `helpers.ts`）
- 避免泛化命名：`utils.ts`、`helpers.ts`、`common.ts` 只用于真正的通用工具集

### 优先级评估

| 因素 | 权重 | 说明 |
|------|------|------|
| 重复次数 | 高 | 出现 5 次 > 出现 2 次 |
| 克隆大小 | 高 | 50 行的克隆 > 5 行的克隆 |
| 变更频率 | 高 | 经常改的代码重复更危险（改一处漏另一处） |
| 所在层次 | 中 | 业务核心 > UI 样式 > 测试辅助 |
| 修复难度 | 低 | 简单的不一定优先，但可以作为 quick win |

### 报告撰写准则

- 每个问题必须有**具体文件路径和行号**
- 建议必须**可直接执行**（"抽取到 X 文件，命名为 Y，签名为 Z"）
- 不使用模糊表述（"考虑优化"、"可以改进"、"建议重构"）
- 对于有争议的建议，标注 trade-off（如"抽取会增加间接层，但消除了 N 处重复"）
