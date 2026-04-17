# Spec Checklist

在开始写 `TechnicalSpec` 前，优先确认以下 9 类信息：

1. **Goal**
   - 该模块要完成什么？
   - 成功后谁会感知到变化？

2. **Source Inputs / Upstream Models**
   - 当前 spec 基于哪些 requirement baseline / ClarifiedRequirement / plan 输入？
   - 如果上游提供了模型，是否明确列出对应 `docs/models/<scenario>/<name>.md`？
   - 如果没有模型，是否明确写 `N/A`？

3. **Scope / Non-Goals**
   - 本模块明确负责什么？
   - 哪些相关内容明确不在本模块负责范围内？

4. **Acceptance Signals**
   - 看到什么结果算该 spec 成立？
   - 测试设计能否直接从这些信号展开？

5. **Rules**
   - 有哪些必须满足的业务规则、派生关系、不变量？
   - 哪些规则来自上游模型，哪些来自 requirement baseline？

6. **Interfaces**
   - 模块接收什么输入？输出什么结果？
   - 是否有外部系统、权限、错误语义或边界契约？

7. **States / State Transitions**
   - 若存在状态机：有哪些状态、哪些转换合法、哪些非法？

8. **Non-Functional Constraints**
   - 是否有性能、安全、合规、兼容性限制？

9. **Assumptions / Questions**
   - 哪些是假设？
   - 哪些问题阻塞下游？
   - 哪些问题不阻塞但仍应记录？

## 写作优先级

默认优先顺序：

1. Goal
2. Source Inputs / Upstream Models
3. Scope / Non-Goals
4. Acceptance Signals
5. Rules
6. Interfaces
7. States / State Transitions
8. Non-Functional Constraints
9. Assumptions / Questions

只有高优先级信息清晰后，才继续细化低优先级部分。

## 何时可以停止补写

满足以下全部条件即可停止补写并产出 `TechnicalSpec`：

- 目标明确
- 输入来源明确；有模型时模型输入明确，没有模型时已显式写 `N/A`
- 模块边界和非目标明确
- 验收信号明确
- 关键业务规则明确
- 对外接口或输入输出契约明确
- 若存在状态变化，转换规则明确
- 不存在会改变测试设计或实现边界的阻塞问题

若仍存在会改变测试设计或实现边界的问题，应写入 `Blocking Questions` 并标记 `Blocked`。

## 审查清单

在审查一份 `TechnicalSpec` 时，优先按以下顺序检查：

### 1. 条件性上游对齐检查

仅当本次输入中提供了 `docs/models/<scenario>/<name>.md` 时执行。

逐条确认：

1. `TechnicalSpec` 中的 `Rules / States / State Transitions` 是否能追溯到上游模型条目？
2. 上游已声明的重要不变量、派生关系、状态变化是否在 `TechnicalSpec` 中有落位？
3. 术语、实体名、字段名是否与上游模型一致？

若未提供上游模型，本节跳过，不构成错误。

### 2. 完整性检查

确认以下内容是否完整：

- `Goal`
- `Source Inputs / Upstream Models`
- `Scope / Non-Goals`
- `Acceptance Signals`
- 关键业务规则
- 关键接口 / 权限 / 错误语义
- 若有状态机：状态与状态转换
- 若有明确非功能要求：性能 / 安全 / 合规 / 兼容性约束
- `Assumptions / Blocking Questions / Open Questions`
- `Status`

### 3. 一致性检查

确认以下内容是否一致：

- 术语是否统一
- 规则之间是否冲突
- 状态、接口、约束是否互相矛盾

### 4. 歧义检查

这是最高价值的审查项。对每条关键 `Rule` 自问：

- 在所有主要输入组合下，行为是否确定？
- 是否存在两种合理解读？
- 边界值（零、空、最大、最小）时行为是否明确？
- 并发、重复操作或重试时行为是否明确？
- 与其他规则组合时是否产生歧义？

### 5. 风险检查

优先检查：

- 安全风险：权限、数据泄露、注入攻击
- 性能风险：大数据量、超时、N+1 查询
- 可靠性风险：并发、幂等、重试
- 兼容性风险：breaking change、迁移影响

### 6. 建议补充

若 `TechnicalSpec` 仍可改进，优先建议：

- 增补缺失章节
- 明确前置条件或依赖
- 明确错误语义、边界行为或状态转换
- 明确必要的非功能约束

## 审查输出建议

每条发现建议带严重度：

- `Critical`: 核心规则错误、安全漏洞、关键行为缺失
- `Major`: 明显遗漏、歧义、关键一致性问题
- `Minor`: 术语、结构、可读性或次要补充问题
- `Info`: 纯观察

若存在无法独立判断的点，应单独列出，不要强行给出结论。
