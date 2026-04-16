# Golden Examples

## Example 1: Delivered

```markdown
# Delivered Change — invoice-export

## Source Spec
- TechnicalSpec: invoice-export

## Source Tests
- tests/invoice-export/service.test.ts
- tests/invoice-export/api.test.ts

## Source Models
- docs/models/domain/invoice-export.md

## Baseline Failures
- In scope: export returns 500, unauthorized role not rejected, timeout requirement not met
- Out of scope: none

## Changed Files
- src/invoice-export/service.ts
- src/invoice-export/api.ts

## Spec Completeness Matrix
| 功能域 | 对应测试 suite | 实现位置 | 状态 | 备注 |
|--------|---------------|---------|------|------|
| CSV export service | tests/invoice-export/service.test.ts | src/invoice-export/service.ts:generateCsv | ✅ Production-ready | |
| Export API auth gate | tests/invoice-export/api.test.ts | src/invoice-export/api.ts:handleExport | ✅ Production-ready | |

## Upstream Coverage Matrix
| upstream 条目 | Scenario ID | spec-ref | Test 位置 | Impl 位置 | 状态 |
|--------------|-------------|----------|----------|----------|------|
| docs/models/domain/invoice-export.md#Entity.ExportJob | S-1 | Acceptance Signals | tests/invoice-export/service.test.ts:18 | src/invoice-export/service.ts:generateCsv | ✅ |
| docs/models/domain/invoice-export.md#Invariant.ExportJob.1 | S-2 | Interfaces | tests/invoice-export/api.test.ts:42 | src/invoice-export/api.ts:handleExport | ✅ |
| docs/models/domain/invoice-export.md#Rel.ExportJob-LegacyPrinter | N/A | Non-Goals | - | - | ⚠️ NOT APPLICABLE + legacy printer integration is explicitly out of scope in this spec |

## Validation
- `npm test -- tests/invoice-export/service.test.ts tests/invoice-export/api.test.ts` ✅
- `npm run typecheck` ✅

## Blockers
- none

## Unfinished Items
- none

## Residual Risks
- 大文件导出性能只做了本地 smoke 验证，完整压测留给 CI 或 benchmark 流程

## Status
- Delivered
```

## Example 2: Blocked

```markdown
# Delivered Change — approval-notification

## Source Spec
- TechnicalSpec: approval-notification

## Source Tests
- tests/approval-notification/service.test.ts

## Source Models
- docs/models/process/approval-notification.md

## Baseline Failures
- In scope: notification channel mismatch, recipient resolution missing
- Out of scope: none

## Changed Files
- none

## Spec Completeness Matrix
| 功能域 | 对应测试 suite | 实现位置 | 状态 | 备注 |
|--------|---------------|---------|------|------|
| Notification dispatch | tests/approval-notification/service.test.ts | - | ❌ Blocked | spec 未明确通知渠道优先级 |

## Upstream Coverage Matrix
| upstream 条目 | Scenario ID | spec-ref | Test 位置 | Impl 位置 | 状态 |
|--------------|-------------|----------|----------|----------|------|
| docs/models/process/approval-notification.md#Process.NotificationDispatch | S-1 | Rules | tests/approval-notification/service.test.ts:15 | - | ❌ |

## Validation
- `npm test -- tests/approval-notification/service.test.ts` ❌

## Blockers
- spec 未明确 email 与 webhook 的优先顺序，继续实现会固化错误契约

## Unfinished Items
- Notification dispatch 尚未开始实现；需先回退并澄清通知渠道优先级

## Residual Risks
- 当前无法判断 email 与 webhook 的优先顺序，继续实现会固化错误契约

## Status
- Blocked
```

为什么是 `Blocked`：当前阻塞点会直接改变实现语义，不能靠猜测落代码。
