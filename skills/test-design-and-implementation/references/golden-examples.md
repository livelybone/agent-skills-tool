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

[S-2][CRITICAL][CONTRACT] 非授权角色尝试调用导出接口
→ 系统拒绝请求且不返回文件
↑ spec-ref: Acceptance Signals, Interfaces

[S-3][PROPERTY] 导出结果只包含当前筛选月份的数据
→ 任意月份输入下都不会混入其他月份记录
↑ spec-ref: Rules

[S-4][INTEGRATION] 文件生成失败时用户重试导出
→ 系统允许从 failed 再次进入 generating
↑ spec-ref: State Transitions

[S-5][INTEGRATION] 导出大月份数据时生成文件
→ 系统仍在 30 秒内完成文件生成
↑ spec-ref: Non-Functional Constraints

## Coverage Notes
- 已覆盖主流程成功路径
- 已覆盖权限边界
- 已覆盖“仅当前月份数据”这一关键规则
- 已覆盖 generating -> failed -> generating 的状态转换
- 已覆盖 30 秒内完成导出的非功能约束

## Filtered Out
- 页面按钮 hover 样式变化（琐碎逻辑，不影响业务风险）

## Status
- Ready for implementation
```

## Example 2: Blocked

```markdown
# Test Scenarios — approval-notification

## Source Spec
- TechnicalSpec: approval-notification

## Scenario List

[S-1][CRITICAL][INTEGRATION] 审批完成后发送通知
→ 系统向定义好的接收对象发送一次通知
↑ spec-ref: Acceptance Signals, Rules

## Coverage Notes
- 当前仍无法确定“接收对象”与“通知渠道”，测试输入输出边界不稳定
- 若现在落测试，后续会因规格变化整体推翻

## Filtered Out

## Status
- Blocked
```

为什么是 `Blocked`：技术文档中的阻塞问题仍会改变测试的输入输出契约，不能继续实现测试。
