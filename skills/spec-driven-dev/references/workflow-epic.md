# Epic 处理：Plan 步骤

当需求为 Epic 时，在进入 spec-driven-dev 流程之前，必须先完成 Plan。

## Plan 的职责

Plan 回答三个问题，**仅此三个**：

1. **What** — 有哪些模块（每个模块的名称和边界）
2. **Order** — 依赖关系（哪些必须串行，哪些可以并行）
3. **Contract** — 模块间接口（上游产出什么，下游消费什么）

Plan **不回答**实现细节（协议格式、API 签名、状态机定义）——这些属于各模块的 Spec。

## Plan 输出格式

每个模块一个条目：

```markdown
## Module: [模块名称]

- **边界**：[这个模块负责构建什么，一句话]
- **模块依赖**：[需要从哪些上游模块消费什么契约，没有则写"无"]
- **产出契约**：[这个模块暴露给下游的接口/能力]
- **复杂度**：[Trivial / Simple / Medium / Complex]
```

加上依赖关系图（文字或 ASCII 表示模块串/并行关系）。

## Plan 的完整流程

```
Epic 需求
  ↓
[Plan 生成]（人描述需求 → AI 生成模块拆解草稿 → 人修订）
  ↓
[Human Plan Review]（确认边界合理、依赖正确、契约完整）
  ↓
按依赖顺序，对每个模块启动独立的 spec-driven-dev 流（完整步骤见 SKILL.md）：
  Module A（Complex）: Spec → Review → Scenario → Review → Tests → Test Review → Red Run → Baseline → Impl → Spec 完整性校验 → CI
  Module B（Medium）:  Spec → Review → Scenario → Tests → Test Review → Red Run → Baseline → Impl → Spec 完整性校验 → CI  ← 依赖 A
  Module C（Simple）:  Spec → Scenario → Tests → Red Run → Baseline → Impl → Spec 完整性校验 → CI                          ← 并行于 B
```

## Plan Review 检查点

人工审查 Plan 时确认：

- ✅ 每个模块边界清晰、职责单一
- ✅ 没有模块承担了它不该承担的职责（实现细节不在 Plan 里）
- ✅ 依赖关系图完整（没有循环依赖，没有遗漏的集成点）
- ✅ 每个模块的产出契约足够明确，下游可以据此写 Spec
- ✅ 并行路径识别合理（可以并行的没有被串行化）
