---
id: NNNN
title: "<一句话决策对象,如:把订单服务事件总线从 RabbitMQ 换成 Kafka>"
status: proposed   # proposed | accepted | superseded
date: YYYY-MM-DD
# --- 三条件 AND gate(全部必填,任一为空或仅含 TODO/<...> 占位会被 check-adr-conditions.sh 拒收)---
irreversibility: |
  <难逆转证据:回滚成本量化(钱/人时/数据迁移规模/对外契约破坏)。
   反例:"性能更好"、"团队更熟悉"——不是难逆转证据。>
surprise-without-context: |
  <"6 个月后的同事会问 why"的合理疑问,至少 1 条。
   反例:"这是最佳实践"——不是上下文,是口号。>
real-tradeoff: |
  <被认真考虑过的备选方案 ≥ 2 个,每个含被否决理由。
   反例:"没有备选"——则不该写 ADR,改回 thinking-guardrails 推演。>
# --- 可选关联 ---
supersedes: []     # 被本 ADR 取代的旧 ADR id 列表,如 [0003]
related-model:     # 可选,modeling-first 文件 + 锚点,仅记录指针,不双向同步
  # path: docs/models/process/event-bus.md
  # anchor: Entity.Bus
---

# ADR-NNNN: <决策对象短标题>

## Context

<决策发生的背景:触发问题、约束、相关方。
 写"是什么环境让这个决定不得不做",不写决策本身。>

## Decision

<我们决定:<具体行动>。一句话。
 紧跟一段说明:这个决定如何回应 Context 中的问题。>

## Consequences

<这个决定带来的(已知)后果。
 - 正面:<得到了什么>
 - 负面:<付出了什么>
 - 中性:<行为变化但难定性>>

## Alternatives

<被认真考虑过的备选 ≥ 2 个,与 frontmatter `real-tradeoff` 对应详化:

### A: <备选 A>

- 描述:
- 否决理由:

### B: <备选 B>

- 描述:
- 否决理由:>

## Notes

<可选:链接、相关讨论、未决问题(不影响本决策成立的)。

如本 ADR 取代旧 ADR,在文件**末尾**追加(已发布 ADR 不可改决策正文,只可追加 supersede 标记):

> Superseded by ADR-MMMM
>
> 取代理由摘要(一句):...
>
本句仅供模板说明,真实使用时把上面这段移到本节末尾或文件末尾。>
