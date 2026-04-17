# Implementation Checklist

在开始实现前，先确认以下 8 类信息：

1. **Spec Readiness**
   - `TechnicalSpec` 是否已是 `Ready for implementation`？
   - 是否仍存在会改变实现边界的 `Blocking Questions`？

2. **Test Readiness**
    - 当前 spec 范围内的测试是否真实存在并可运行？
    - 是否能看出哪些测试属于本次实现范围，并且每条都带 `Scenario ID` 与 `@scenario` / `@spec-ref` / `@upstream`？
    - spec 中每个声明的功能域是否都有对应的可执行测试？

3. **Model Constraints**
   - 是否存在必须遵守的 `docs/models/<scenario>/<name>.md`？
   - 是否已知道哪些实体、关系、不变量、派生关系需要在实现中落地？

4. **Baseline**
   - 是否已在写代码前运行当前 spec 范围内测试？
   - 是否已区分范围内失败和无关失败？

5. **Implementation Scope**
   - spec 中定义了哪些功能域、服务、组件或流程？
   - 哪些地方仍是 stub、`not implemented` 或根本未落地？

6. **Edit Boundaries**
   - 是否只会改实现代码，而不去重写已批准测试？
   - 若测试看起来不合理，是否会停止并回退上游，而不是直接改测试？

7. **Verification**
   - 范围内测试是否全部通过？
   - 与本次改动相关的 typecheck / lint / build 是否已运行？

8. **Delivery Report**
   - `Spec Completeness Matrix` 是否覆盖了每个功能域？
   - `Upstream Coverage Matrix` 是否覆盖了每个相关模型锚点，并保留精确的 `Scenario ID`（或显式 `N/A`）与 `spec-ref`？

## 交付前停止条件

出现以下任一情况时，不能标记为 `Delivered`：

- `TechnicalSpec` 仍是 `Blocked`
- 仍存在会改变实现语义的 `Blocking Questions` 或 spec 歧义
- 当前 spec 范围内测试缺失或无法运行
- 当前消费的测试缺少 `Scenario ID`、`@scenario`、`@spec-ref` 或 `@upstream` 追溯
- 某个 spec 功能域没有对应的可执行测试
- 关键实现仍是 stub、`throw new Error('not implemented')` 或临时硬编码
- spec、测试与模型之间存在语义冲突
- `Spec Completeness Matrix` 仍有 `❌` 项
- `Upstream Coverage Matrix` 仍有遗漏条目，或缺少精确的 `Scenario ID`（或显式 `N/A`）/ `spec-ref`

## 何时可以标记为 Delivered

满足以下全部条件即可交付：

- 当前 spec 范围内 baseline 失败已全部消除
- 当前消费的测试具备 `Scenario ID` 与 `@scenario` / `@spec-ref` / `@upstream` 最小追溯
- 每个 spec 功能域都有对应的可执行测试
- 每个功能域都有生产级实现
- 已运行本次相关验证命令并记录结果
- 不存在会改变实现语义的 `Blocking Questions` 或 spec 歧义
- 相关模型锚点都已覆盖，且保留精确的 `Scenario ID`（或显式 `N/A`）/ `spec-ref`；若 `NOT APPLICABLE`，也有具体且合理的 `spec-ref` 与理由
- 无需通过改测试、改 spec 或加临时逻辑来维持通过
