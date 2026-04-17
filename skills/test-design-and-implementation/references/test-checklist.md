# Test Checklist

在开始设计测试与审查已实现测试前，优先按以下顺序确认这 12 类信息（条目排列即默认优先级）：

1. **Acceptance Signals**
   - 什么结果算该 `TechnicalSpec` 成立？
   - 哪些结果最值得先变成测试？

2. **Main Flow**
   - 主流程是什么？
   - 哪个路径最能代表 feature 成功？

3. **Rules**
   - 有哪些关键业务规则、不变量、派生关系？
   - 若 `Upstream Models` 非 `N/A`：这些规则是否还隐含关系约束、导出公式或 ownership / 删除语义？

4. **Interfaces**
   - 有哪些输入/输出、错误语义、权限边界？
   - 是否需要至少一个 `[CONTRACT]` 场景来保护这些契约？

5. **States**
   - 若存在状态机：哪些状态转换必须覆盖？哪些必须禁止？

6. **Failure And Edge Cases**
   - 是否系统检查了空值、缺失值、边界值、非法状态、权限边界？
   - 是否存在外部依赖失败、数据不一致、并发/重入等高风险失败路径？

7. **Non-Functional Constraints**
   - 是否存在可测试的性能、安全、兼容性或合规行为？

8. **Scenario Marking**
   - 每个保留场景是否带了合理的测试类型（`CONTRACT / INTEGRATION / PROPERTY`，必要时 `UNIT`）？
   - 涉及 contract / money / permission / state transition / data integrity 的高风险场景是否标了 `[CRITICAL]`？
   - 场景是否引入了 `TechnicalSpec` 或 `Upstream Models` 未声明的新行为？若有，应先回修上游文档，而不是直接写测试

9. **Scenario Review**
    - 是否已通过跨 agent 审查检查主流程、失败路径、危险边界和 expansion pass 补充场景？
    - `[CRITICAL]` 和测试类型标记是否经独立审查后仍成立？
    - 每个场景的 `upstream-ref` 是否真实、必要，且没有伪造引用或应写 `N/A + 具体理由` 却被省略？
    - 若审查发现会改变测试边界的问题，是否已回退到 `tech-spec-writing`？

10. **Overtest Filter**
   - 哪些候选场景其实在测私有 helper、实现细节、琐碎逻辑或重复路径？

11. **Test Review**
    - 是否已通过跨 agent 审查检查 `Scenario -> Test` 翻译是否完整？
    - 每个高风险场景是否都有对应测试，且关键断言没有缺口？
    - 是否存在测试越出场景边界、偷偷扩展语义或转而测试实现路径？
    - 是否存在 `@scenario` / `@spec-ref` / `@upstream` 断链、错链或伪造引用？
    - 是否存在 `skip` / `todo` / `xit` / `xtest`、弱断言或只验证导出/文件存在的假完成测试？

12. **Traceability And Red Run Preconditions**
    - 每个保留场景是否有唯一 `Scenario ID`？
    - 每个保留场景是否都带 `spec-ref` 和合法的 `upstream-ref`？
    - 每个场景是否能映射到一个或多个测试？
    - 每个已实现测试是否都带 `@scenario`、`@spec-ref`、`@upstream`？
    - 测试文件位置和命名是否遵循仓库现有模式，或符合 `references/repo-structure.md`？
    - 被测模块能否成功 import？
    - 若不能，是否已建立无业务逻辑的 stub？
    - stub 是否只保证公开契约和 import 可解析，而没有偷带业务逻辑、硬编码返回值或真实副作用？

## 何时可以停止补写场景

满足以下全部条件即可停止补写并进入测试实现：

- 已覆盖至少一个主流程成功路径
- 已覆盖全部 `[CRITICAL]` 场景
- 若存在外部契约、权限边界或错误语义，已覆盖至少一个 `[CONTRACT]` 场景
- 关键业务规则和危险边界已覆盖
- 关键失败路径已覆盖，且不是只复述 spec 中已经列出的示例
- 若存在状态变化，关键合法/非法转换已覆盖
- 若 `Upstream Models` 非 `N/A`，关键不变量、派生关系或关系约束已转成场景
- 跨 agent 场景审查已完成，且 findings 已被裁决
- 若存在可测试的非功能约束，已覆盖对应场景
- 明显的 overtest 候选已删除

若缺少会改变测试设计边界的信息，应回退到 `tech-spec-writing`。
