# Test Checklist

在开始设计测试前，优先确认以下 9 类信息：

1. **Acceptance Signals**
   - 什么结果算该 `TechnicalSpec` 成立？
   - 哪些结果最值得先变成测试？

2. **Main Flow**
   - 主流程是什么？
   - 哪个路径最能代表 feature 成功？

3. **Rules**
   - 有哪些关键业务规则、不变量、派生关系？

4. **Interfaces**
   - 有哪些输入/输出、错误语义、权限边界？
   - 是否需要至少一个 `[CONTRACT]` 场景来保护这些契约？

5. **States**
   - 若存在状态机：哪些状态转换必须覆盖？哪些必须禁止？

6. **Non-Functional Constraints**
   - 是否存在可测试的性能、安全、兼容性或合规行为？

7. **Overtest Filter**
   - 哪些候选场景其实在测私有 helper、实现细节、琐碎逻辑或重复路径？

8. **Traceability**
   - 每个保留场景是否有唯一 `Scenario ID`？
   - 每个场景是否能映射到一个或多个测试？

9. **Red Run Preconditions**
   - 被测模块能否成功 import？
   - 若不能，是否已建立无业务逻辑的 stub？

## 设计优先级

默认优先顺序：

1. Acceptance Signals
2. Main Flow
3. Rules
4. Interfaces
5. States
6. Non-Functional Constraints
7. Overtest Filter
8. Traceability
9. Red Run Preconditions

## 何时可以停止补写场景

满足以下全部条件即可停止补写并进入测试实现：

- 已覆盖至少一个主流程成功路径
- 已覆盖全部 `[CRITICAL]` 场景
- 若存在外部契约、权限边界或错误语义，已覆盖至少一个 `[CONTRACT]` 场景
- 关键业务规则和危险边界已覆盖
- 若存在状态变化，关键合法/非法转换已覆盖
- 若存在可测试的非功能约束，已覆盖对应场景
- 明显的 overtest 候选已删除

若缺少会改变测试设计边界的信息，应回退到 `tech-spec-writing`。
