# Clarification Checklist

在进入建模前，优先检查以下 7 类信息是否明确：

1. **Goal**
   - 这次需求到底要解决什么问题？
   - 成功后谁会感知到变化？

2. **Actor**
   - 谁发起动作？
   - 谁接收结果或受影响？

3. **Trigger**
   - 什么条件下会发生这件事？
   - 是主动发起、定时任务，还是事件驱动？

4. **In Scope**
   - 本次明确要交付哪些能力？
   - 是否包含前后端、通知、权限、历史数据迁移？

5. **Out of Scope**
   - 哪些看起来相关但这次不做？
   - 是否有二期内容需要明确排除？

6. **Constraints**
   - 是否有平台、依赖系统、上线时间、合规、兼容性限制？

7. **Acceptance Signals**
   - 看到什么结果算需求完成？
   - 是否有明确的业务指标、页面结果、接口行为或错误语义？

## 提问优先级

默认优先顺序：

1. Goal
2. In Scope / Out of Scope
3. Trigger
4. Actor
5. Acceptance Signals
6. Constraints

只有当高优先级问题已清晰时，才继续问低优先级问题。若 `Trigger` 或 `Actor` 缺失，必须在结束追问前补齐。

## 何时可以停止追问

满足以下全部条件即可停止追问并产出 `ClarifiedRequirement`：

- 主路径目标明确
- 关键角色明确
- 明确写出 `Out of Scope`
- 触发条件明确
- 交付范围明确
- 至少一个验收信号明确
- 关键约束不会改变主路径实现方向
- 未决点不会改变核心业务语义或模块边界

若仍存在会改变主路径行为的未决点，应写入 `Blocking Questions` 并标记 `Blocked`。

若未决点不会阻塞下游，可写入 `Open Questions`，但状态仍可为 `Ready for downstream`。
