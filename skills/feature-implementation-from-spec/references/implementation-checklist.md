# Implementation Checklist

> 交付门槛由 `SKILL.md` 的「验收标准」和「质量门槛」定义。本清单是实现过程中的辅助提问，帮助快速发现漏项；**不重复**交付门槛定义，避免双份维护。

## 实现前（Pre-Implementation）

1. **Spec Readiness**
   - `TechnicalSpec.Status` 是否为 `Ready for test/design`，且测试产物 `Status` 为 `Ready for implementation`？
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
   - 若 baseline 意外全绿，是否已停止并回退 `test-design-and-implementation`？

5. **Implementation Scope**
   - spec 中定义了哪些功能域、服务、组件或流程？
   - 哪些地方仍是 stub、`not implemented` 或根本未落地？

## 实现中（During）

6. **Edit Boundaries**
   - 是否只会改实现代码，而不去重写已批准测试？
   - 若测试看起来不合理，是否会停止并回退上游，而不是直接改测试？

## 交付前自检（Pre-Delivery Self-Check）

> 对应 `SKILL.md` 的验收标准与质量门槛，此处只做快速提问，判定以 SKILL.md 为准。

7. **Verification**
   - 范围内测试是否全部通过？
   - 与本次改动相关的 typecheck / lint / build 是否已运行且全部通过？

8. **Delivery Report**
   - `Spec Completeness Matrix` 是否覆盖了每个功能域？
   - `Upstream Coverage Matrix` 是否覆盖了每个相关模型锚点，并保留精确的 `Scenario ID`（或显式 `N/A`）与 `spec-ref`？
