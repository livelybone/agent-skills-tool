# Test Scenarios — <feature-name>

## Source Spec
- <TechnicalSpec path or identifier>

## Scenario List

> Keep each scenario as human-readable behavior prose. Do not write test function names or internal call sequences.

[S-1][CRITICAL][INTEGRATION] <用户执行操作>
→ <系统行为>
↑ spec-ref: <Acceptance Signals / Rules / State Transitions>
↑ upstream-ref: <domain/order.md#Invariant.Order.3 or N/A + reason>

[S-2][CONTRACT] <接口或契约行为>
→ <系统行为>
↑ spec-ref: <Interfaces / Rules>
↑ upstream-ref: <domain/order.md#Rel.Order-User>

[S-3][PROPERTY] <不变量或属性>
→ <系统行为>
↑ spec-ref: <Rules>
↑ upstream-ref: <domain/order.md#Invariant.Order.3>

[S-4][INTEGRATION] <状态转换对应的可测试行为>
→ <系统行为>
↑ spec-ref: <State Transitions>
↑ upstream-ref: <state-machine/order.md#StateMachine.Order>

[S-5][INTEGRATION] <非功能约束对应的可测试行为>
→ <系统行为>
↑ spec-ref: <Non-Functional Constraints>
↑ upstream-ref: <N/A + explain why no upstream model applies>

## Coverage Notes
- <哪些 Acceptance Signals / Rules / 状态转换已覆盖>

## Filtered Out
- <被判定为 overtest 而删除的候选场景，可为空>

## Status
- Ready for implementation | Blocked

## Red Run

> 仅在 `Status = Ready for implementation` 时填写；`Blocked` 时整节删除或保留 "N/A (Blocked)"。

- Command: `<运行本次新增/修改测试的命令>`
- Executed Tests: `<S-1, S-2, ... 对应的测试用例清单>`
- Expected Failure Mode: `<not implemented / stub throws / feature 未接线>`
- Observed Failures:
  - `<Scenario ID> — <失败信息>`
- Unexpected Signals: `<import 错误、语法错误等；若无则写 "none"；有则说明已如何修正后重跑>`

> If `Status = Blocked`, explain the blocking reason in `Coverage Notes`.
> If `Status = Ready for implementation`, every implemented test should carry `@scenario <Scenario ID>`, `@spec-ref <section>`, and `@upstream <doc>#<anchor>` or `@upstream N/A + <reason>`.
