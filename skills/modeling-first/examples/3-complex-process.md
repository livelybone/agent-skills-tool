# 示例 3：复杂流程建模（多步审批 + 回滚）

**需求原文**：
> 报销单提交后需走三级审批：直属主管 → 部门经理 → 财务。任一级驳回则退回申请人修改。财务审批通过后自动发起打款，打款失败需通知财务人工处理。

**触发信号识别**：多步操作 + 条件分支 + 回滚/补偿 → 文件级建模（full）

**建模单元拆分**（按 Source of Truth 规则）：

- `docs/models/domain/expenses.md` — **业务实体主权**：ExpenseReport 聚合（根 + 内部 ApprovalStep）、派生、不变量、业务状态机
- `docs/models/process/expense-reimbursement.md` — **流程主权**：打款结算的 Steps/Rollback；审批流程本身由 domain 的状态机承载，process 只负责审批通过后的打款流程
- `docs/models/domain/payments.md` 已存在 → 增量引用

本示例展示两份建模文件，以及它们的分工。

---

## docs/models/domain/expenses.md（业务实体属主）

```md
**Unit**: `domain/expenses`
**Context**: 报销单业务模型（含三级审批语义）
**Source**: <需求来源>
**Date**: 2026-04-15

## Aggregates（本单元持有）
<!-- anchor: Aggregate.ExpenseReport -->
- ExpenseReport Aggregate — 根：ExpenseReport — 内部：ApprovalStep

## 1. Entities
<!-- anchor: Entity.ExpenseReport -->
- ExpenseReport — 需求依据："报销单" — 新建
<!-- anchor: Entity.ApprovalStep -->
- ApprovalStep — 需求依据："三级审批"引入（ExpenseReport 聚合内部实体，不独立存在）— 新建

## 2. Relationships
<!-- anchor: Rel.ExpenseReport-ApprovalStep -->
- ExpenseReport ↔ ApprovalStep — 1:N — ExpenseReport 持有 ApprovalStep — 级联删

## 3. Derivation Chains
<!-- anchor: Derivation.ExpenseReport.currentLevel -->
- ExpenseReport.currentLevel = count(approvalSteps where status='approved')
<!-- anchor: Derivation.ExpenseReport.isTerminal -->
- ExpenseReport.isTerminal = status in {'paid', 'pay_failed', 'rejected'}

## 4. Invariants
<!-- anchor: Invariant.ExpenseReport.1 -->
- amount > 0
<!-- anchor: Invariant.ExpenseReport.2 -->
- 已驳回的审批步骤不能跳过直接进入下一级
<!-- anchor: Invariant.ApprovalStep.1 -->
- approver !== ExpenseReport.applicant（不能自己审批自己）
<!-- anchor: Invariant.ApprovalStep.2 -->
- level 递进顺序严格 L1 → L2 → L3，不得跳级

## State Machine — ExpenseReport（可选章节）
<!-- anchor: StateMachine.ExpenseReport -->
States: draft | pending_l1 | pending_l2 | pending_l3 | approved | paying | paid | pay_failed | rejected
Transitions:
  draft → pending_l1        guard: submit          action: notify L1 approver
  pending_l1 → pending_l2   guard: L1 approve      action: notify L2 approver
  pending_l1 → rejected     guard: L1 reject       action: notify applicant
  pending_l2 → pending_l3   guard: L2 approve      action: notify L3 approver
  pending_l2 → rejected     guard: L2 reject       action: notify applicant
  pending_l3 → approved     guard: L3 approve      action: trigger Payment Settlement process
  pending_l3 → rejected     guard: L3 reject       action: notify applicant
  approved → paying         guard: PaymentSettlementStarted event    action: —
  paying → paid             guard: PaymentSettled event              action: notify applicant
  paying → pay_failed       guard: PaymentSettlementFailed event     action: notify finance
  approved → pay_failed     guard: PaymentSettlementInitFailed event action: notify finance（首步失败 → 不进 paying）
  rejected → draft          guard: applicant edit                    action: clear approvals
```

---

## docs/models/process/expense-reimbursement.md（流程主权）

流程单元纯粹聚焦于"审批通过后的打款结算流程"，业务实体通过 upstream-ref 引用：

```md
**Unit**: `process/expense-reimbursement`
**Context**: ExpenseReport 审批通过后的打款结算流程（Payment Settlement）
**Source**: <需求来源>
**Date**: 2026-04-15

## Aggregates（本单元持有）
<!-- anchor: Aggregate.none -->
- 非 domain 单元，不持有业务聚合。所有业务实体通过 upstream-ref 引用。

## 1. Entities
| 实体 | 依据 | 位置 |
|------|------|------|
| ExpenseReport | 流程输入 | `upstream-ref: docs/models/domain/expenses.md#Entity.ExpenseReport` |
| Payment | 流程产出 | `upstream-ref: docs/models/domain/payments.md#Entity.Payment` |

## 2. Relationships
### 跨单元关系
<!-- anchor: Rel.Process-ExpenseReport -->
- Payment Settlement 流程与 domain/expenses 的交互
  - 契约：`ref: process/expense-reimbursement reads ExpenseReport.status, ExpenseReport.amount, ExpenseReport.applicant from domain/expenses`（启动前校验）
  - 契约：`event: PaymentSettlementStarted from process/expense-reimbursement → domain/expenses`（触发 approved → paying）
  - 契约：`event: PaymentSettlementInitFailed from process/expense-reimbursement → domain/expenses`（首步失败，触发 approved → pay_failed）
  - 契约：`event: PaymentSettled from process/expense-reimbursement → domain/expenses`（成功，触发 paying → paid）
  - 契约：`event: PaymentSettlementFailed from process/expense-reimbursement → domain/expenses`（失败，触发 paying → pay_failed）
<!-- anchor: Rel.Process-Payment -->
- 流程调用 domain/payments 执行实际打款
  - 契约：`cmd: process/expense-reimbursement calls Pay(amount, applicant) on domain/payments`
  - 契约：`ref: process/expense-reimbursement reads Payment.status from domain/payments`

## 3. Derivation Chains
（流程自身无派生；业务派生属 `domain/expenses`）

## 4. Invariants
<!-- anchor: Invariant.Process.cross.1 -->
- **[跨模块]** 本流程仅当 ExpenseReport.status === 'approved' 时启动
  - 涉及：`upstream-ref: docs/models/domain/expenses.md#StateMachine.ExpenseReport`
  - 执行者：本单元（process）启动前校验

## 5. Reuse Check
| 需要 | 已有 | 决策 |
|------|------|------|
| 打款网关 | <payment-gateway 封装> | 复用 |
| 失败通知 | <notification 模块> | 复用 |

## 6. Open Questions
- [ ] 打款失败后人工介入的具体工单流程是否已确定？
- [ ] `retry 3x` 的具体退避策略？

## Process Model — Payment Settlement（本单元核心产出）
<!-- anchor: Process.PaymentSettlement -->
Steps:
  1. create_payment_record  → fail: emit PaymentSettlementInitFailed（domain 据此 approved → pay_failed，通知财务）
  2. emit PaymentSettlementStarted  → domain 据此 approved → paying
  3. call_payment_gateway   → fail: emit PaymentSettlementFailed（domain 据此 paying → pay_failed，通知财务）
  4. confirm_settlement     → retry 3x；成功 emit PaymentSettled；仍失败 emit PaymentSettlementFailed
Rollback: 所有状态变化通过 event 通知 domain，流程不直接修改 domain 状态；打款失败不自动回滚审批状态，由财务人工处理
Concurrency: 无
```

---

**如何指导实现**：

1. **业务规则在 domain**：ExpenseReport 聚合（含内部 ApprovalStep）、审批语义（包括"不能跳级"、"不能自审自批"）、业务状态机全部在 `domain/expenses.md`。所有引用方通过 upstream-ref 消费
2. **process 单元的职责极简**：只负责审批通过后的"打款结算流程"，不混入业务状态语义
3. **跨单元契约显式**：`process` 启动条件通过 `ref` 契约表达，完成通过 `event` 契约通知 domain 推进状态，防止实现时流程随意操作 domain 数据
4. **防模式匹配**：业务状态机定义所有合法转换路径（含驳回后重新提交），Process 明确打款失败不回滚审批状态，阻止 coding-agent 套"失败全回滚"的通用模板
