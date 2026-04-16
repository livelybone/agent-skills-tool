# Delivered Change — <feature-name>

## Source Spec
- <TechnicalSpec path or identifier>

## Source Tests
- <test files or suites used for this delivery>

## Source Models
- <docs/models/<scenario>/<name>.md or N/A>

## Baseline Failures
- In scope: <failing tests before implementation>
- Out of scope: <pre-existing unrelated failures or none>

## Changed Files
- <implementation files changed>

## Spec Completeness Matrix
| 功能域 | 对应测试 suite | 实现位置 | 状态 | 备注 |
|--------|---------------|---------|------|------|
| <feature/service/component> | <tests/...> | <src/...:line or symbol> | ✅ Production-ready | |

> `Status = Delivered` 时，`对应测试 suite` 不得为空、`-` 或占位文本。

## Upstream Coverage Matrix
| upstream 条目 | Scenario ID | spec-ref | Test 位置 | Impl 位置 | 状态 |
|--------------|-------------|----------|----------|----------|------|
| <docs/models/...#Anchor> | <verbatim Scenario ID, e.g. S-1> | <verbatim @spec-ref, e.g. Rules> | <tests/...:line> | <src/...:line or symbol> | ✅ |
| <docs/models/...#Anchor> | <N/A> | <verbatim excluded spec-ref, e.g. Non-Goals> | <tests/...:line or -> | <src/...:line or -> | ⚠️ NOT APPLICABLE + <reason> |

## Validation
- <commands run and results>

## Blockers
- <blocking reason or none>

## Unfinished Items
- <unfinished implementation items or none>

## Residual Risks
- <remaining risks or none>

## Status
- Delivered | Blocked
