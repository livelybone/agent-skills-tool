# Step E: 识别流程结构（适用时）

**触发信号**：任务涉及多步操作、条件分支、并发/竞态、或回滚/补偿逻辑。典型场景：

- 多步审批：提交 → 初审 → 复审 → 终审，每步可能驳回
- 事务流程：下单 → 扣库存 → 扣款 → 发货，失败时需回滚前置步骤
- 向导型交互：多步表单，前置步骤的输入决定后续步骤的结构

**产出格式**：

- **Steps**：有序步骤列表
- **Conditions**：步骤间的分支条件
- **Rollback**：失败时的补偿动作（如有）
- **Concurrency**：哪些步骤可并行、竞态如何处理（如有）

```
Steps:
  1. validate_input    → fail: return error
  2. reserve_stock     → fail: return error
  3. charge_payment    → fail: rollback(release_stock)
  4. create_shipment   → fail: rollback(refund_payment, release_stock)
  5. send_confirmation → fail: log warning (non-critical, no rollback)
Concurrency: steps 4 and 5 can run in parallel after step 3 succeeds
```

**与实体建模的配合**：流程中的每个步骤通常对应一个实体的行为或状态转换。流程建模关注步骤间的顺序、条件和补偿，不替代实体级的不变量和派生关系。
