# Golden Examples

## Example 1: Ready for test/design

```markdown
# Technical Spec — invoice-export

## Goal
让财务运营能从结算页面导出指定月份的开票记录 CSV。

## Source Inputs
- ClarifiedRequirement: invoice-export
- Models: domain/billing-export.md
- Optional Plan: N/A

## Scope
- 结算页面增加导出入口
- 服务端生成指定月份的 CSV
- 只导出固定字段：发票号、客户名、金额、开票时间、状态

## Non-Goals
- 不支持 Excel
- 不支持自定义导出字段
- 不做历史数据修复

## Acceptance Signals
- 财务可以下载指定月份的 CSV 文件
- 非授权角色既看不到入口，也不能通过接口触发导出

## Rules
- 仅管理员和财务角色可触发导出 [source: requirement]
- 导出文件只包含当前筛选月份的数据 [source: requirement]
- 文件生成失败时返回明确错误提示，不生成空文件 [source: model]

## Interfaces
- 输入：月份筛选值、当前用户身份
- 输出：CSV 文件下载或明确错误响应
- 权限边界：无权限用户看不到导出入口，也不能调用导出接口

## States
- idle
- generating
- ready
- failed

## State Transitions
- idle -> generating：用户点击导出
- generating -> ready：文件生成成功
- generating -> failed：文件生成失败
- failed -> generating：用户重试导出

## Non-Functional Constraints
- 文件需在 30 秒内生成完成

## Assumptions
- 现有账单服务已能按月份查询开票记录

## Blocking Questions

## Open Questions
- [ ] 文件名是否需要包含租户名

## Status
- Ready for test/design
```

## Example 2: Blocked

```markdown
# Technical Spec — approval-notification

## Goal
在审批完成后自动通知相关人员。

## Source Inputs
- ClarifiedRequirement: approval-notification
- Models: domain/approval.md, process/approval-notification.md
- Optional Plan: approval-flow module

## Scope
- 在审批完成后触发通知发送

## Non-Goals
- 不改审批流本身的状态机
- 不重构通知基础设施

## Acceptance Signals
- 审批流完成后，定义好的接收对象能收到一次通知

## Rules
- 审批流进入 completed 后必须触发一次通知逻辑 [source: model]

## Interfaces
- 输入：审批完成事件
- 输出：通知发送请求

## Assumptions
- 现有通知基础设施可复用

## Blocking Questions
- [ ] 接收对象是否仅发起人，还是包含抄送人与处理链相关人员？
- [ ] 渠道是否只有站内信，还是还要支持邮件与短信？

## Open Questions
- [ ] 通知文案是否区分通过 / 拒绝两种语气

## Status
- Blocked
```

为什么是 `Blocked`：接收对象和通知渠道会直接改变接口、测试场景和实现边界，不能继续下游执行。
