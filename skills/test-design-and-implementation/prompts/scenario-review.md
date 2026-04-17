# 提示模板 — 跨 agent 审查测试场景

本文件仅作为 `multi-agent-loop` 的审查指令正文模板复用，不是可直接传给 `run_agent.sh` 的协议 prompt 文件。

使用独立 agent 审查当前 `Test Scenarios`，目标是找出覆盖缺口、错误标记、越界场景和过度测试问题。

## 输入

- `TechnicalSpec`
- 当前 `Test Scenarios`
- 若 `TechnicalSpec` 的 `Upstream Models` 非 `N/A`：对应建模文件

### 1. Coverage Gaps

- 是否遗漏主流程、失败路径、危险边界
- 是否遗漏外部契约、权限边界、错误语义
- 是否遗漏状态转换、非功能约束
- 若存在 `Upstream Models`：是否遗漏关键不变量、派生关系或关系约束

### 2. Scenario Marking

- `[CRITICAL]` 标记是否合理
- `CONTRACT / INTEGRATION / PROPERTY / UNIT` 类型是否合理
- 每个场景的 `upstream-ref` 是否真实、必要，且符合全局 `upstream-ref` 规范
- expansion pass 新补场景是否真的有明确业务风险支撑

### 3. Scope Violations

- 场景是否引入了 `TechnicalSpec` 未声明的新行为
- 若存在 `Upstream Models`：场景是否越过模型边界，测试未建模的行为

### 4. Overtest Findings

- 哪些场景在测私有 helper、实现细节、琐碎逻辑、脆弱快照或重复路径
- 对每个问题说明：为什么属于 overtest；删除后是否仍保留真实业务风险覆盖

## 严重度

级别类型固定为 `Critical / Major / Minor / Info` 四档（`multi-agent-loop` 协议不变量）。本任务下的具体含义如下——controller 合成 `agent-task.md` 时把这四行原样写入 `<严重度定义块>` 槽位：

- `[Critical]`：场景缺口或越界会直接导致错误功能约束、安全/权限风险、资金风险、数据完整性风险，或让后续测试建立在错误边界上
- `[Major]`：重要主流程、失败路径、契约风险、关键状态转换遗漏；会实质影响测试覆盖边界，必须修正
- `[Minor]`：非关键覆盖优化、标记优化、轻微重复；不改变核心测试边界
- `[Info]`：观察，无需动作

## 审查原则

- 聚焦场景质量，不审查测试代码实现
- 优先指出会改变测试边界或交付风险的缺口
- 不重写整份场景列表，只给出 findings
- 对新增补充场景，必须说明不测试会造成什么具体业务风险
