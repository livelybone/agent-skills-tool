# Golden Examples

## Example 1: Ready for downstream

```markdown
# Clarified Requirement — invoice-export

## Goal
允许财务同学导出指定月份的开票记录，减少手工整理时间。

## Actors
- 财务运营
- 后端账单服务

## Trigger
财务运营在结算页面点击“导出开票记录”。

## In Scope
- 在结算页面增加“导出开票记录”入口
- 支持按月份导出 CSV
- 导出字段固定为发票号、客户名、金额、开票时间、状态

## Out of Scope
- 不支持自定义字段
- 不支持 Excel 格式
- 不处理历史数据修复

## Constraints
- 仅管理员和财务角色可导出
- 导出文件需在 30 秒内生成

## Acceptance Signals
- 财务可成功下载指定月份的 CSV
- 非授权角色看不到导出入口

## Facts
- 现有结算页已经有月份筛选
- 开票记录已存在后端查询接口

## Assumptions
- CSV 编码使用 UTF-8

## Blocking Questions

## Open Questions
- [ ] 文件名是否需要包含租户名

## Status
- Ready for downstream
```

为什么是 `Ready`：主路径目标、角色、触发条件、范围、约束和验收信号都清晰；剩余问题不会改变核心行为或模块边界。

## Example 2: Blocked

```markdown
# Clarified Requirement — approval-notification

## Goal
在审批完成后通知相关人员。

## Actors
- 审批发起人
- 审批处理人

## Trigger
审批流进入“完成”状态。

## In Scope
- 在审批完成后发送通知

## Out of Scope
- 不改审批流状态机本身

## Constraints
- 需要复用现有通知基础设施

## Acceptance Signals
- 审批完成后，相关人员能收到通知

## Facts
- 系统已有站内信和邮件两种通知能力

## Assumptions
- 审批完成事件已有统一事件源

## Blocking Questions
- [ ] “相关人员”具体是仅发起人，还是发起人 + 抄送人 + 当前处理链全部人？
- [ ] 通知渠道是只发站内信，还是邮件、短信也要一起发？

## Open Questions
- [ ] 通知文案是否需要区分通过 / 拒绝两种语气

## Status
- Blocked
```

为什么是 `Blocked`：虽然目标和触发条件存在，但接收对象和通知渠道都会改变范围、下游接口和模块边界，不能继续建模或编排。
