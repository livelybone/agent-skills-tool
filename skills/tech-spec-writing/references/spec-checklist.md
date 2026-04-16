# Spec Checklist

在开始写 `TechnicalSpec` 前，优先确认以下 8 类信息：

1. **Goal**
   - 该模块要完成什么？
   - 成功后谁会感知到变化？

2. **Scope / Non-Goals**
   - 本模块明确负责什么？
   - 哪些相关内容明确不在本模块负责范围内？

3. **Acceptance Signals**
   - 看到什么结果算该 spec 成立？
   - 测试设计能否直接从这些信号展开？

4. **Rules**
   - 有哪些必须满足的业务规则、派生关系、不变量？
   - 哪些规则来自上游模型，哪些来自 requirement baseline？

5. **Interfaces**
   - 模块接收什么输入？输出什么结果？
   - 是否有外部系统、权限、错误语义或边界契约？

6. **States**
   - 若存在状态机：有哪些状态、哪些转换合法、哪些非法？

7. **Constraints**
   - 是否有性能、安全、合规、兼容性限制？

8. **Assumptions / Questions**
   - 哪些是假设？
   - 哪些问题阻塞下游？
   - 哪些问题不阻塞但仍应记录？

## 写作优先级

默认优先顺序：

1. Goal
2. Scope / Non-Goals
3. Acceptance Signals
4. Rules
5. Interfaces
6. States
7. Constraints
8. Assumptions / Questions

只有高优先级信息清晰后，才继续细化低优先级部分。

## 何时可以停止补写

满足以下全部条件即可停止补写并产出 `TechnicalSpec`：

- 目标明确
- 模块边界和非目标明确
- 验收信号明确
- 关键业务规则明确
- 对外接口或输入输出契约明确
- 若存在状态变化，转换规则明确
- 不存在会改变测试设计或实现边界的阻塞问题

若仍存在会改变测试设计或实现边界的问题，应写入 `Blocking Questions` 并标记 `Blocked`。
