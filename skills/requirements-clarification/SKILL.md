---
name: requirements-clarification
description: "把模糊需求澄清为可执行的 ClarifiedRequirement，产出范围、假设、约束、未决点，供 modeling-first 或 spec-driven-dev 消费。触发词：需求澄清、clarify requirement、补充需求、梳理需求、明确范围。"
metadata:
  version: 0.1.0
  tags:
    - requirements
    - clarification
    - product
    - pre-modeling
---

# Requirements Clarification

把模糊需求收敛成可执行的 `ClarifiedRequirement`，让下游不靠猜测继续推进。

## 适用场景

- 用户只有一句话或几句模糊描述，目标和边界还不清楚
- 已有 PRD / issue / 聊天记录，但缺少关键输入，无法直接进入建模或技术方案
- 需求涉及多个可能方向，需要先确定 scope / out-of-scope / success criteria
- 在调用 `modeling-first` 或 `spec-driven-dev` 之前，先判断需求是否已足够清晰

## 必须材料

- 原始需求描述（用户原话、issue、PRD、会议纪要至少一种）
- 已知约束：时间、平台、角色、依赖系统、合规要求（如有）
- 现有上下文：相关页面、接口、流程、截图、代码位置（如有）

若材料不完整，本 skill 的职责是显式暴露缺口，而不是替用户补完业务语义。

## 执行步骤

1. **识别缺口**
   - 先按以下维度扫描原始需求是否缺信息：`goal / actor / trigger / in-scope / out-of-scope / constraints / acceptance signals`
   - 若 `goal / actors / in-scope / out-of-scope / acceptance signals / trigger / key constraints` 已清晰，且没有会改变主路径语义的阻塞项：可直接生成 `ClarifiedRequirement`
   - 缺 2 项以上或主路径不明确：进入问题澄清

2. **提出高杠杆问题**
   - 只问最影响后续决策的问题，优先级：`目标` > `范围（含 out-of-scope）` > `触发条件` > `关键角色` > `成功标准` > `限制条件`
   - 单轮问题数默认不超过 5 个
   - 问题必须具体，不问“还有什么补充吗”这类低信息量问题
   - 若 `trigger` 或 `actors` 缺失，则必须在结束追问前补齐，不能留给下游从 `Facts` 自行提取

3. **整理需求基线**
   - 基于用户回答和现有上下文，产出 `ClarifiedRequirement`
   - 明确区分：
      - **Facts**：用户已确认的信息
      - **Assumptions**：为推进而暂定的前提
      - **Blocking Questions**：仍阻塞下游推进的未决点
      - **Open Questions**：仍待确认但不阻塞下游的未决点

4. **判断可交付性**
   - 若目标、角色、范围、`Out of Scope`、触发条件、成功标准、关键约束已清晰，且不存在会改变模块边界或核心行为的阻塞项：标记 `Ready for downstream`
   - 若仍存在会改变模块边界或核心行为的未决点：标记 `Blocked`，并列出阻塞问题

5. **交棒下游**
   - 进入建模：交给 `modeling-first`
   - 进入前置编排：交给 `spec-driven-dev`

## 产物与格式

### 主要产物

- **ClarifiedRequirement**：使用 `assets/templates/clarified-requirement.md`

### 模板

模板单一真源：`assets/templates/clarified-requirement.md`

关键字段：

- `Goal`
- `Actors`
- `Trigger`
- `In Scope`
- `Out of Scope`
- `Constraints`
- `Acceptance Signals`
- `Facts`
- `Assumptions`
- `Blocking Questions`
- `Open Questions`
- `Status: Ready for downstream | Blocked`

Golden examples：见 `references/golden-examples.md`

### 验收标准

- 下游看到产物后，能判断是否可以进入 `modeling-first`
- 下游看到产物后，能判断是否可以进入 `spec-driven-dev`
- 产物中没有把“事实”和“假设”混写
- `Blocked` 状态必须说明阻塞点，不允许只写“信息不足”

## 质量门槛

> 遵循全局上下文中的“代码质量基础规范”

### 本 skill 特定检查

- [ ] 所有问题都直指后续决策所需信息，而非泛泛追问
- [ ] `Goal / Actors / Trigger / In Scope / Out of Scope / Acceptance Signals / Constraints` 七项齐全
- [ ] `Trigger` 明确可见，不隐藏在 `Facts` 中
- [ ] `Facts / Assumptions / Open Questions` 三类信息明确分栏
- [ ] `Blocking Questions` 与非阻塞 `Open Questions` 明确区分
- [ ] `Out of Scope` 明确写出本次不做的内容，防止范围膨胀
- [ ] 若状态为 `Ready for downstream`，下游无需再靠猜测补全主路径语义

## 验证方式

> 遵循全局上下文中的“验证方式通用流程”

### 本 skill 特定验证

1. 让阅读者回答：是否知道本次到底要解决什么问题？
2. 让阅读者回答：是否知道本次明确不做什么？
3. 让阅读者回答：是否知道还缺什么信息、这些缺口是否阻塞建模？
4. 若 1-3 中任一回答为否，说明澄清产物仍不够清晰

## 不覆盖范围

- 不负责领域建模、状态机建模、流程建模
- 不负责 Epic plan 或模块拆解
- 不负责技术文档、测试用例、实现代码
- 不替代产品决策；遇到真实业务语义分叉必须升级给用户

## 覆盖声明

无

## 引用资料

- `assets/templates/clarified-requirement.md` — 标准产物模板
- `references/clarification-checklist.md` — 澄清维度与提问优先级清单
- `references/golden-examples.md` — `Ready` / `Blocked` 示例产物
