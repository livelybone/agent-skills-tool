# Domain Model — spec-driven-dev Skill 内容结构

**Context**: 重构 spec-driven-dev skill 的文件组织与内容，消除跨文件重复、修正内容错放、补齐缺失
**Source**: 用户要求 + 内容全量分析
**Date**: 2026-04-14

---

## 1. Entities

spec-driven-dev 的内容由以下领域概念组成：

<!-- anchor: Entity.WorkflowMode -->
- **WorkflowMode** — 流程执行模式（Standard / Auto / Epic）。决定步骤集合、审查方式、产物要求。需求依据：SKILL.md 入口判断逻辑

<!-- anchor: Entity.Step -->
- **Step** — 流程中的原子步骤（建模/Spec 生成/Scenario 生成/Test 实现/Feature 实现/CI 等）。有编号、前置依赖、是否必选。需求依据：SKILL.md 流程定义

<!-- anchor: Entity.Artifact -->
- **Artifact** — 步骤的产物文件（model.md / spec.md / scenario / test / implementation / decision-log / decision-report / plan / coverage-matrix）。需求依据：各 workflow 文档 + templates/

<!-- anchor: Entity.Review -->
- **Review** — 质量门禁，插在步骤之间。两种形态：人工审查（Standard）、跨 agent 审查（Auto，经 multi-agent-loop）。需求依据：SKILL.md 跨 Agent 审查原则

<!-- anchor: Entity.PromptTemplate -->
- **PromptTemplate** — 给 AI 执行步骤或审查任务的指令模板。每个对应一个 Step 或 Review。需求依据：`prompts/*.md`（9 个文件）

<!-- anchor: Entity.SharedRule -->
- **SharedRule** — 跨多个步骤/模板共享的约束规则（如 upstream-ref 语法、overtest 过滤清单、测试类型标记）。已收敛为独立文件：`guides/upstream-ref.md`（upstream-ref 唯一定义点）、`guides/testing.md`（测试指南唯一定义点，含 overtest 清单）。需求依据：内容分析发现的 6+ 处重复 → 已修复

<!-- anchor: Entity.Guide -->
- **Guide** — 特定领域的参考指南（复杂度判定、迭代回退、仓库结构、场景格式）。按需查阅，不绑定到特定步骤。需求依据：`guides/` 目录下的指南文件

<!-- anchor: Entity.Template -->
- **Template** — 产物的文件模板（spec.md / plan.md 骨架 + frontmatter）。需求依据：templates/

<!-- anchor: Entity.ProgressCheckpoint -->
- **ProgressCheckpoint** — 嵌入在 Artifact frontmatter 中的进度状态（current_step, status, context_summary）。用于跨会话续接。需求依据：SKILL.md 进度检查点章节

---

## 2. Relationships

<!-- anchor: Rel.WorkflowMode-Step -->
- **WorkflowMode → Step** — 1:N — WorkflowMode 定义其包含的步骤集合及顺序。Standard 有步骤 0-11，Auto 有 0-13，Epic 在外层包裹 Plan + 模块遍历。删除模式 = 删除对应步骤定义

<!-- anchor: Rel.Step-Artifact -->
- **Step → Artifact** — 1:N — 一个步骤产出一个或多个 Artifact（如 Test Implementation 产出测试文件 + stub 文件）。Artifact 不脱离 Step 存在

<!-- anchor: Rel.Step-Review -->
- **Step → Review** — 1:0..1 — 步骤后可选跟一个 Review 门禁。是否有 Review 取决于 WorkflowMode + 复杂度。Review 不脱离 Step 存在

<!-- anchor: Rel.Review-PromptTemplate -->
- **Review → PromptTemplate** — 1:1 — 每个审查任务对应一个 prompt 模板。PromptTemplate 可被多个 Review 复用（如 spec-review 在 Standard 和 Auto 都用）

<!-- anchor: Rel.Step-PromptTemplate -->
- **Step → PromptTemplate** — 1:0..1 — 执行类步骤（非审查）也可能有 prompt（如 scenario-generation, test-implementation, feature-implementation）

<!-- anchor: Rel.PromptTemplate-SharedRule -->
- **PromptTemplate → SharedRule** — N:N — 多个 prompt 引用同一条 SharedRule（如 overtest 清单被 scenario-review、test-review、test-expansion 共用）。SharedRule 独立于 PromptTemplate 存在

<!-- anchor: Rel.Step-Guide -->
- **Step → Guide** — N:N — 步骤执行时按需查阅 Guide。Guide 独立于 Step 存在，可服务多个步骤

<!-- anchor: Rel.Artifact-Artifact -->
- **Artifact → Artifact (upstream-ref)** — N:1 — 下游 Artifact 通过 upstream-ref 追溯上游（model → spec → scenario → test → impl）。这是可追溯性链条的核心

<!-- anchor: Rel.Artifact-ProgressCheckpoint -->
- **Artifact ↔ ProgressCheckpoint** — 1:0..1 — 嵌入关系（frontmatter）。只有 spec.md 和 plan.md 携带 checkpoint

<!-- anchor: Rel.Artifact-Template -->
- **Artifact → Template** — N:1 — Artifact 按 Template 骨架生成。Template 独立存在

---

## 3. Derivation Chains

### 根变量

- `WorkflowMode.type: Standard | Auto | Epic`
- `Step.complexity: Low | Medium | High`（由 complexity-guide 判定）

### 派生值

<!-- anchor: Derivation.Review.type -->
- `Review.type = if WorkflowMode == Auto then "cross-agent" else "human"` — 审查形态由模式决定

<!-- anchor: Derivation.Step.isRequired -->
- `Step.isRequired = Step.alwaysRequired || (complexity >= Step.minComplexity)` — 步骤 0/7/8.5/10/11 始终必选，其余按复杂度

<!-- anchor: Derivation.Step.reviewDepth -->
- `Step.reviewDepth = f(WorkflowMode, complexity)` — Auto 强制全深度；Standard 按复杂度可选

<!-- anchor: Derivation.PromptTemplate.sharedConstraints -->
- `PromptTemplate.effectiveRules = PromptTemplate.ownRules ∪ SharedRule[referenced]` — prompt 的有效约束 = 自有规则 + 引用的共享规则。SharedRule 已收敛为独立文件（`guides/upstream-ref.md`、`guides/testing.md`），prompt 通过链接引用

---

## 4. Invariants

### WorkflowMode

<!-- anchor: Invariant.WorkflowMode.1 -->
- `WorkflowMode.type in {'Standard', 'Auto', 'Epic'}`

<!-- anchor: Invariant.WorkflowMode.2 -->
- `Epic 模式必须先产出 Plan 再进入模块级 Spec 层`（不允许跳过 Plan）

### Step

<!-- anchor: Invariant.Step.1 -->
- `模块内步骤严格串行`（不允许并行执行同一模块的不同步骤）

<!-- anchor: Invariant.Step.2 -->
- `步骤 N 的输入 = 步骤 N-1 的已审查产物`（上游未审查 → 下游不启动）

### Artifact

<!-- anchor: Invariant.Artifact.1 -->
- `每个 Artifact 的 upstream-ref 必须指向已存在的锚点`（不允许虚假引用）

<!-- anchor: Invariant.Artifact.2 -->
- `model.md 中的锚点一旦发布不得删除或重命名`（除非同步更新所有下游引用）

### Review

<!-- anchor: Invariant.Review.1 -->
- `跨 agent 审查必须通过 multi-agent-loop 启动`（禁止用 Agent tool subagent 替代）

<!-- anchor: Invariant.Review.2 -->
- `审查最多 3 轮`（有界循环）

<!-- anchor: Invariant.Review.3 -->
- `Auto 模式下审查不可降级或跳过`（"改动小"、"上下文长"不是跳过理由）

### SharedRule

<!-- anchor: Invariant.SharedRule.1 -->
- `每条 SharedRule 只在一个文件中定义`（单一真理源），其他文件只链接引用。已修复：upstream-ref 收敛至 `guides/upstream-ref.md`，overtest 收敛至 `guides/testing.md`

### ProgressCheckpoint

<!-- anchor: Invariant.ProgressCheckpoint.1 -->
- `每个步骤完成后必须立即更新 checkpoint`（硬性要求）

<!-- anchor: Invariant.ProgressCheckpoint.2 -->
- `checkpoint 足以让新会话从断点续接`（包含 current_step, status, context_summary）

---

## 5. Reuse Check

| 需要的能力 | 已有 | 决策 |
|-----------|------|------|
| upstream-ref 语法定义 | 原 6+ 处 → 已收敛 | `guides/upstream-ref.md`（唯一定义点），其余已改为链接 |
| overtest 过滤清单 | 原 4 处 → 已收敛 | `guides/testing.md` > Overtest 过滤清单（唯一定义点），其余已改为链接 |
| 测试类型标记定义 | `guides/scenario-format.md` | 保留为唯一定义，其余链接 |
| Red Run 协议 | 原 workflow-standard → 已收敛 | `guides/testing.md` > Red Run 协议（唯一定义点），workflow 已改为链接 |
| Implementation Stub 规则 | 原 prompt-test-implementation → 已收敛 | `guides/testing.md` > Implementation Stub 规则（唯一定义点），prompt 已改为链接 |
| 跨 agent 审查规则 | SKILL.md + workflow-auto | 保留在 SKILL.md（核心不变量），workflow-auto 引用不重复 |

---

## 6. Open Questions

以下问题已在本轮重构中解决：

- [x] `testing-guide.md` → 已扩充为 `guides/testing.md`（160 行），吸收 Stub、Red Run、overtest
- [x] `complexity-guide.md` → 保留为独立 `guides/complexity.md`（5 处引用）
- [x] Decision Report 完整性 → `workflows/auto.md` 已明确为"检查时状态"语义
- [x] Spec 生成方式 → 以 `guides/complexity.md` 4 档分级为权威，`workflows/standard.md` 改为链接

---

## 模型对重构的指导

从模型可以直接推导出文件组织方式——**每个实体类型 = 一个目录**：

| 实体 | 目录 | 说明 |
|------|------|------|
| WorkflowMode + Step 定义 | `workflows/` | 三种模式各一个文件（已完成）|
| PromptTemplate | `prompts/` | 每个执行/审查任务一个文件（已完成）|
| SharedRule + Guide | `guides/` | 共享规则 + 指南（已完成：upstream-ref.md、testing.md 为唯一定义点）|
| Template | `templates/` | 不变 |
| Artifact + ProgressCheckpoint | 不需要独立文件 | 定义在 SKILL.md 和 templates 中 |

**Invariant.SharedRule.1** 已通过本轮重构修复：upstream-ref 语法、overtest 清单、Stub 规则、Red Run 协议均已收敛为单一定义点。
