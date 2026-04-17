---
name: tech-spec-writing
description: "把完整需求或前置 handoff contract 翻译成可执行的 TechnicalSpec，明确业务规则、接口契约、状态变化和非目标，供测试设计与功能实现消费。触发词：写技术文档、tech spec、技术方案、spec writing、设计文档。"
metadata:
  version: 0.1.0
  tags:
    - spec
    - design
    - architecture
    - handoff
---

# Tech Spec Writing

把完整需求和前置 handoff contract 翻译成可执行的 `TechnicalSpec`，让下游测试设计和功能实现不再靠口头理解推进。

## 适用场景

- 已有完整需求或 `ClarifiedRequirement`，需要转成技术文档
- 已有 `modeling-first` 产物，需要把领域模型落成模块级技术规格
- 已有 Epic plan，需要在模块边界内写出单模块 `TechnicalSpec`
- 需要为后续 `test-design-and-implementation` 或 `feature-implementation-from-spec` 提供统一输入

## 必须材料

- 以下任一输入形态：
  - 完整需求 + 可选的相关 `docs/models/<scenario>/<name>.md`
  - `ClarifiedRequirement` + 可选的相关 `docs/models/<scenario>/<name>.md`
  - 来自 `spec-driven-dev` 的 handoff contract：`requirement baseline + optional models + optional plan + optional review notes`
- 若需求属于 Epic 中的某个模块：该模块对应的边界描述或 `plan` 条目
- 现有约束：接口边界、权限规则、性能/合规要求、兼容性要求（如有）

若没有模型而需求又引入新领域信息，本 skill 应停止并要求先完成 `modeling-first`。

## 执行步骤

1. **确认输入边界**
   - 确认本次 spec 对应的是单模块还是单一功能片段
   - 若上游有 `plan`，必须先锁定当前模块边界，禁止越界扩写其他模块职责

2. **抽取规格骨架**
   - 从 requirement baseline / `ClarifiedRequirement` 中提取：`goal / scope / constraints / acceptance signals`
   - 从模型中提取：`rules / derivations / invariants / states / transitions / process constraints`
   - 从 `plan` 中提取：模块边界和上游/下游契约

3. **写出 `TechnicalSpec`**
   - 用模板 `assets/templates/technical-spec.md`
   - 只写下游执行所需的行为与契约，不写实现代码或测试细节
   - 若模块涉及状态机或流程，显式写 `States` / `State Transitions`
   - 若提供了上游建模产物，就把其中的规则、状态和约束吸收到 `TechnicalSpec`；若没有，也可基于现有 requirement baseline / ClarifiedRequirement / plan 正常写 spec

4. **处理缺口**
   - 能被更保守解释消化的歧义：在 `Assumptions` 中记录
   - 会改变模块边界、核心规则或外部契约的歧义：写入 `Blocking Questions`，状态标记为 `Blocked`
   - 不阻塞的遗留问题：写入 `Open Questions`

5. **判断可交付性**
   - 若规则、契约、状态变化、非目标和阻塞点都已清晰：标记 `Ready for test/design`
   - 若仍缺少会改变测试设计或实现边界的信息：标记 `Blocked`

6. **交棒下游**
   - 产出 `TechnicalSpec`，供下游阶段消费

## 产物与格式

### 主要产物

- **TechnicalSpec**：使用 `assets/templates/technical-spec.md`

### 模板

模板单一真源：`assets/templates/technical-spec.md`

关键字段：

- `Goal`
- `Source Inputs`
- `Upstream Models`（有模型时必填；没有模型时写 `N/A`）
- `Scope`
- `Non-Goals`
- `Acceptance Signals`
- `Rules`
- `Interfaces`
- `States`（可选）
- `State Transitions`（可选）
- `Non-Functional Constraints`（可选）
- `Assumptions`
- `Blocking Questions`
- `Open Questions`
- `Status: Ready for test/design | Blocked`

Golden examples：见 `references/golden-examples.md`

### 验收标准

- 下游看到产物后，能直接开始设计测试场景
- 下游看到产物后，能知道本模块明确不做什么
- 下游看到产物后，能知道什么结果算该 spec 成立
- 若上游提供了模型，下游看到产物后，能知道本 spec 依赖了哪些模型输入
- 若涉及状态变化，状态与转换规则不靠猜测
- `Blocked` 状态必须把真正阻塞测试/实现的问题写进 `Blocking Questions`

## 质量门槛

> 遵循全局上下文中的“代码质量基础规范”

### 本 skill 特定检查

 - [ ] `Goal / Source Inputs / Scope / Non-Goals / Acceptance Signals / Rules / Interfaces` 七项齐全
 - [ ] 有上游模型时，`Upstream Models` 已填写；没有模型时明确写 `N/A`
 - [ ] 所有业务规则都来自 requirement baseline、模型或 plan，而不是凭空补设，且在 spec 中可追溯
- [ ] 若模型里存在不变量、派生关系或状态机，spec 中有对应落位
 - [ ] `Assumptions`、`Blocking Questions` 与非阻塞 `Open Questions` 明确区分
- [ ] 产物不包含测试代码、实现代码或具体文件级实现步骤
- [ ] 若状态为 `Ready for test/design`，下游无需再靠猜测补全主路径语义

## 验证方式

> 遵循全局上下文中的“验证方式通用流程”

### 本 skill 特定验证

1. 让阅读者回答：这个模块到底要做什么、不做什么？
2. 让阅读者回答：有哪些必须满足的规则和接口约束？
3. 让阅读者回答：什么结果算该 spec 成立？
4. 若涉及状态变化，让阅读者回答：哪些转换合法、哪些非法？
5. 让阅读者回答：哪些问题阻塞下游，哪些只是遗留问题？
6. 若 1-5 中任一回答为否，说明 `TechnicalSpec` 仍不够清晰

## 不覆盖范围

- 不负责需求澄清
- 不负责领域建模、状态机建模、流程建模本身
- 不负责测试实现或功能实现
- 不负责 Epic plan 编排或模块拆解

## 覆盖声明

无

## 引用资料

- `assets/templates/technical-spec.md` — 标准产物模板
- `references/spec-checklist.md` — 编写与审查清单
- `references/golden-examples.md` — `Ready` / `Blocked` 示例产物
