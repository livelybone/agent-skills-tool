# Golden Examples

## Example 1: Ready for implementation

```markdown
# Test Scenarios — invoice-export

## Source Spec
- TechnicalSpec: invoice-export

## Scenario List

[S-1][CRITICAL][INTEGRATION] 财务运营点击导出指定月份发票
→ 系统生成并返回对应月份的 CSV 文件
↑ spec-ref: Acceptance Signals, Rules
↑ upstream-ref: process/invoice-export.md#Process.InvoiceExport

[S-2][CRITICAL][CONTRACT] 非授权角色尝试调用导出接口
→ 系统拒绝请求且不返回文件
↑ spec-ref: Acceptance Signals, Interfaces
↑ upstream-ref: domain/invoice-export.md#Rel.InvoiceExport-User

[S-3][PROPERTY] 导出结果只包含当前筛选月份的数据
→ 任意月份输入下都不会混入其他月份记录
↑ spec-ref: Rules
↑ upstream-ref: domain/invoice-export.md#Invariant.InvoiceExport.1

[S-4][INTEGRATION] 文件生成失败时用户重试导出
→ 系统允许从 failed 再次进入 generating
↑ spec-ref: State Transitions
↑ upstream-ref: state-machine/invoice-export.md#StateMachine.InvoiceExport

[S-5][INTEGRATION] 导出大月份数据时生成文件
→ 系统仍在 30 秒内完成文件生成
↑ spec-ref: Non-Functional Constraints
↑ upstream-ref: N/A + 当前约束仅来自 TechnicalSpec 的非功能目标，尚无对应建模锚点

[S-6][UNIT] CSV 文件名遵循 `invoice-<YYYY-MM>.csv` 格式
→ 纯命名规则，无法在 INTEGRATION 场景中稳定断言，仅单独验证
↑ spec-ref: Rules
↑ upstream-ref: N/A + 命名规则仅存在于 TechnicalSpec，无对应建模锚点

## Coverage Notes
- 已覆盖主流程成功路径
- 已覆盖权限边界
- 已覆盖“仅当前月份数据”这一关键规则
- 已覆盖 generating -> failed -> generating 的状态转换
- 已覆盖 30 秒内完成导出的非功能约束
- 已覆盖文件名格式这一孤立规则（UNIT）

## Filtered Out
- 页面按钮 hover 样式变化（琐碎逻辑，不影响业务风险）

## Status
- Ready for implementation

## Red Run

- Command: `pnpm test src/invoice-export/__tests__/invoice-export.test.ts`
- Executed Tests: S-1, S-2, S-3, S-4, S-5, S-6 对应的 6 个测试用例
- Expected Failure Mode: stub throws `not implemented`
- Observed Failures:
  - S-1 — `Error: not implemented` (exportInvoices)
  - S-2 — `Error: not implemented` (exportInvoices)
  - S-3 — `Error: not implemented` (exportInvoices)
  - S-4 — `Error: not implemented` (retryExport)
  - S-5 — `Error: not implemented` (exportInvoices)
  - S-6 — `Error: not implemented` (exportInvoices)
- Unexpected Signals: none
```

### 对应测试文件示例

仅展示追溯三元组（`@scenario` / `@spec-ref` / `@upstream`）与场景的一一对应方式，不代表框架选型：

```ts
// src/invoice-export/__tests__/invoice-export.test.ts
// @spec TechnicalSpec: invoice-export

import { describe, it, expect } from 'vitest';
import { exportInvoices, retryExport } from '../invoice-export';

describe('invoice-export', () => {
  // @scenario S-1
  // @spec-ref Acceptance Signals, Rules
  // @upstream process/invoice-export.md#Process.InvoiceExport
  it('财务运营导出指定月份时返回对应月份的 CSV', async () => {
    const file = await exportInvoices({ month: '2026-03', actor: 'finance-ops' });
    expect(file.contentType).toBe('text/csv');
    expect(file.rows.every((r) => r.month === '2026-03')).toBe(true);
  });

  // @scenario S-2
  // @spec-ref Acceptance Signals, Interfaces
  // @upstream domain/invoice-export.md#Rel.InvoiceExport-User
  it('非授权角色调用导出时被拒绝且不返回文件', async () => {
    await expect(
      exportInvoices({ month: '2026-03', actor: 'guest' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  // @scenario S-3
  // @spec-ref Rules
  // @upstream domain/invoice-export.md#Invariant.InvoiceExport.1
  it('任意月份输入下导出结果都只包含该月份记录', async () => {
    for (const month of ['2025-12', '2026-01', '2026-02']) {
      const file = await exportInvoices({ month, actor: 'finance-ops' });
      expect(file.rows.every((r) => r.month === month)).toBe(true);
    }
  });

  // @scenario S-4
  // @spec-ref State Transitions
  // @upstream state-machine/invoice-export.md#StateMachine.InvoiceExport
  it('generating 失败后允许重试重新进入 generating', async () => {
    const job = await retryExport({ jobId: 'failed-job-1', actor: 'finance-ops' });
    expect(job.state).toBe('generating');
  });

  // @scenario S-5
  // @spec-ref Non-Functional Constraints
  // @upstream N/A + 当前约束仅来自 TechnicalSpec 的非功能目标，尚无对应建模锚点
  it('大月份数据量下仍在 30 秒内完成导出', async () => {
    const started = Date.now();
    await exportInvoices({ month: '2025-12', actor: 'finance-ops' });
    expect(Date.now() - started).toBeLessThan(30_000);
  });

  // @scenario S-6
  // @spec-ref Rules
  // @upstream N/A + 命名规则仅存在于 TechnicalSpec，无对应建模锚点
  it('导出文件名符合 invoice-<YYYY-MM>.csv 格式', async () => {
    const file = await exportInvoices({ month: '2026-03', actor: 'finance-ops' });
    expect(file.filename).toBe('invoice-2026-03.csv');
  });
});
```

关键点：

- 每个测试都在紧邻 `it(...)` 上方写出 `@scenario / @spec-ref / @upstream` 三元组，与场景表逐项对应
- 场景中 `upstream-ref: N/A + <reason>` 的，测试里也写成 `@upstream N/A + <reason>`，不要换成伪造锚点或直接省略
- stub 阶段测试应因 `not implemented` 而红，不得通过；这与上面的 `Red Run` 记录一致

## Example 2: Blocked

```markdown
# Test Scenarios — approval-notification

## Source Spec
- TechnicalSpec: approval-notification

## Scenario List

[S-1][CRITICAL][INTEGRATION] 审批完成后发送通知
→ 系统向定义好的接收对象发送一次通知
↑ spec-ref: Acceptance Signals, Rules
↑ upstream-ref: N/A + 阻塞问题尚未澄清接收对象与通知渠道，当前无法稳定映射到建模锚点

## Coverage Notes
- 当前仍无法确定“接收对象”与“通知渠道”，测试输入输出边界不稳定
- 若现在落测试，后续会因规格变化整体推翻

## Filtered Out

## Status
- Blocked
```

为什么是 `Blocked`：技术文档中的阻塞问题仍会改变测试的输入输出契约，不能继续实现测试。
