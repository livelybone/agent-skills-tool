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

> If `Status = Blocked`, explain the blocking reason in `Coverage Notes`.
> If `Status = Ready for implementation`, every implemented test should carry `@scenario <Scenario ID>`, `@spec-ref <section>`, and `@upstream <doc>#<anchor>` or `@upstream N/A + <reason>`.
