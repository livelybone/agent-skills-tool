---
name: adr-recorder
description: "架构决策记录 skill,三条件 AND gate(难逆转 ∧ 没上下文会惊讶 ∧ 真实取舍)由 script 机械校验,通过后产 ADR。触发词:ADR, architecture decision, 架构决策, 不可逆, 决策记录"
metadata:
  version: 0.1.0
  tags:
    - adr
    - architecture-decision
    - point-in-time
    - irreversibility
---

# ADR Recorder

把"我们决定换 Postgres / 用单体不用微服务 / 选 Kafka 而不是 RabbitMQ"这类真实架构决策固化为可追溯的 point-in-time 快照。本 skill 只做"决策已发生 → 写 ADR"这一段,不做决策推演(那是 modeling-first 的歧义 slot),不做运行时反馈(那是 debugging),不做模块抽象审查(那是 code-review)。

## 适用场景

- 团队已经做出一个**难逆转的取舍**(换数据库、改协议、拆/合服务边界、引入新依赖等),需要把"为什么"和"放弃了什么"留下来给 6 个月后的人看
- 用户会话里出现 `ADR / architecture decision / 架构决策 / 不可逆 / 决策记录` 任一触发词,且决策对象具体可命名
- 已有 ADR 被新决定取代,需要用 supersede 链接旧 ADR 而**不是改写旧 ADR**
- modeling-first 的 `docs/models/<scenario>/<name>.md` 中"已知歧义"slot 被一个真实决策解决,需要把决策固化为 ADR(由宿主 coding agent 在收到 `AdrPublished` 事件后刷新 slot)

不适用:写代码前的设计权衡(用 thinking-guardrails 的奥卡姆/建模思维)、运行时已观察到 bug 的诊断(用 debugging)、PR 已写完的结构性审查(用 code-review)、活文档式的领域建模(用 modeling-first)。

## 必须材料

- **决策对象**(必填):一句话能讲清"做了什么"——例如"把订单服务的事件总线从 RabbitMQ 换成 Kafka"。模糊的"我们要优化数据库"不进入流程
- **三条件素材**(全部必填):
  - **难逆转**:回滚成本 ≥ 1 周或涉及数据迁移/对外契约破坏的具体描述(钱、时间、上下游协议)
  - **没上下文会惊讶**:列举至少一个"6 个月后的同事会问 why"的合理疑问
  - **真实取舍**:至少 2 个被认真考虑过的备选方案 + 各自被否决的理由(不能写"性能更好"这类无信息表述)
- **ADR 编号位**:`docs/adr/` 目录(若不存在则本 skill 第一次执行时创建);新编号 = 现有最大编号 + 1,4 位补零
- **slug**:从决策对象提炼的 kebab-case 短语,≤ 6 词,例如 `switch-to-kafka` / `monolith-not-microservice`
- **(可选) 关联 model 锚点**:若该决策回应了 `docs/models/<scenario>/<name>.md` 的"已知歧义"slot,在 ADR `related-model` frontmatter 字段中记录,**仅记录指针,不双向同步内容**(承载 `Invariant.Process.cross.5` 时间语义互斥)

## 执行步骤

3 步顺序硬约束:**禁止跳过 gate 直接写文件**(承载 `Invariant.AdrRecorderSkill.1`)。每步定义"输入 → 动作 → 输出 → 进入下一步的 gate"。

### 1. Gate(三条件 AND 校验,机械)

- **输入**:决策对象一句话 + 三条件素材
- **动作**:把三条件素材填入 frontmatter 候选块,调用 `scripts/check-adr-conditions.sh <draft-file>` 机械校验三字段非空且语义齐备
- **输出**:gate 通过 → 进入步骤 2;任一不满足 → 退回报错并指明哪条缺失,不创建文件
- **进入下一步的 gate**:`check-adr-conditions.sh` 退出码 0,且 stdout 显式列出三条件全部 PASS。**未通过 gate 不允许进入 Draft。**

### 2. Draft(填充 ADR 模板)

- **输入**:gate 通过的三条件素材 + 决策对象 + 备选方案清单
- **动作**:从 `templates/adr.template.md` 拷贝到 `docs/adr/NNNN-<slug>.md`,填充 frontmatter(`id / title / status / date / irreversibility / surprise-without-context / real-tradeoff / supersedes / related-model`)与正文五节(Context / Decision / Consequences / Alternatives / Notes)
- **输出**:`docs/adr/NNNN-<slug>.md` 一份,status=`proposed` 或 `accepted`(由调用方决定);frontmatter 三条件字段非空
- **进入下一步的 gate**:文件已落盘,frontmatter 可被 yaml 解析,正文五节齐全(标题用 `## Context` 等)

### 3. Publish(发布 + emit 事件)

- **输入**:已 draft 的 ADR 文件
- **动作**:status 改为 `accepted`(若曾为 proposed);若该 ADR 取代旧 ADR,在旧 ADR **追加**(不是改写旧决策内容)`> Superseded by ADR-MMMM`(承载 `Invariant.AdrRecorderSkill.2`);emit `AdrPublished` 事件(见"产物与格式")
- **输出**:`docs/adr/NNNN-<slug>.md` status=accepted;旧 ADR(若有)末尾追加 supersede 标记;`AdrPublished` 事件草稿(由宿主 coding agent 消费)
- **完成定义校验**:存在 `docs/adr/NNNN-<slug>.md`,status=accepted,frontmatter 三字段非空,`check-adr-conditions.sh` 仍 PASS

## 产物与格式

### `docs/adr/NNNN-<slug>.md`(单条 ADR)

最小骨架由 `templates/adr.template.md` 提供。要求:

- 文件名格式:`NNNN-<slug>.md`(NNNN 4 位补零,从 0001 起)
- frontmatter 必填字段:`id / title / status / date / irreversibility / surprise-without-context / real-tradeoff`
- frontmatter 可选字段:`supersedes`(被本 ADR 取代的旧 ADR id 列表)、`related-model`(modeling-first 文件路径 + 锚点)
- 正文五节:Context / Decision / Consequences / Alternatives / Notes,标题固定中英文混排不强制
- **已发布 ADR 禁止改写决策内容**(承载 `Invariant.AdrRecorderSkill.2`):只允许追加 `> Superseded by ADR-MMMM` 行到文件末尾
- **不引入回流机制**(承载 `Invariant.Process.cross.5`):不同步刷新 ADR 内容追上 model.md 的演进,新决定写新 ADR + supersede 旧 ADR

### `AdrPublished` 事件(发给 host steering 的契约)

最小 schema:

```json
{
  "adr-id": "<NNNN,required,如 0001>",
  "adr-path": "<repo-relative path,required,如 docs/adr/0001-switch-to-kafka.md>",
  "title": "<string,required,与 frontmatter title 一致>",
  "supersedes": "<array<string>,optional,被取代的旧 ADR id 列表>",
  "related-model": "<string,optional,modeling-first 文件 + 锚点,如 docs/models/process/event-bus.md#Entity.Bus>",
  "session-id": "<optional,host 注入>"
}
```

字段语义:

- `adr-id` / `adr-path` / `title` 三字段为 **required**——任一缺失或为空字符串则 **不发出事件**;adr-recorder 不直接写入 modeling-first 的 model 文件,只 emit 事件
- `session-id` 为 optional,由 host 注入
- 由宿主 coding agent 在后续触发 modeling-first 时消费(承载 `Rel.AdrRecorderSkill-ModelingFirstSkill-ambiguity` 的 event 契约):刷新对应 model 的"已知歧义"slot 标 `resolved by ADR-NNNN`
- 序列化格式与 host steering 接入点延到 modeling-first v3 集成时定

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"

### 本 skill 特定检查

- [ ] **三条件 AND gate**:`scripts/check-adr-conditions.sh <draft>` 退出码 0,且三条件字段(irreversibility / surprise-without-context / real-tradeoff)全部非空且不只含模板占位符;任一不满足则不允许进入 Draft 步骤(承载 `Invariant.AdrRecorderSkill.1`)
- [ ] **3 步顺序**:Gate(check 脚本通过)→ Draft(文件落盘)→ Publish(status=accepted + emit 事件);禁止"直接写一个 ADR 文件然后回填三条件"(机械校验:Draft 阶段时 frontmatter 三字段必须由 Gate 阶段产生的非空候选填入)
- [ ] **完成定义**:存在 `docs/adr/NNNN-<slug>.md`,status=accepted,且通过本 skill 的 check 脚本(承载 `Invariant.AdrRecorderSkill.1`)
- [ ] **ADR 不可改决策**(承载 `Invariant.AdrRecorderSkill.2`):git diff 已发布 ADR 不允许动决策正文(Context / Decision / Consequences / Alternatives 节);只允许追加 `> Superseded by ADR-MMMM` 行
- [ ] **时间语义互斥**(承载 `Invariant.Process.cross.5`):本 SKILL.md 与 `templates/adr.template.md` 不得引入"刷新 ADR 追上 model.md""同步 ADR 与 model"等回流语义;新决定一律写新 ADR + supersede,不改旧 ADR 决策内容
- [ ] **触发词不越界**(承载 `Invariant.Process.cross.1`):本 skill 触发词 `ADR / architecture decision / 架构决策 / 不可逆 / 决策记录` 不与现有 16 个 skill 的 description 触发词重叠(主动 grep `description:` 字段)
- [ ] **产物路径不越界**(承载 `Invariant.Process.cross.2`):只写 `docs/adr/NNNN-<slug>.md`;**禁止写** `.debug/`、`docs/models/`、`.code-review/`、`~/self-improving/`
- [ ] **边界互斥**(与 debugging):本 skill 不进入"运行时反馈环"语义,不在执行步骤中调用 reproduce / hypothesise / instrument / fix / regress 等 debugging 词汇

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定验证

1. 让阅读者回答:这次 ADR 的 id 是什么?决策对象一句话是什么?——指不出即未闭环
2. 让阅读者回答:三条件每一条都有具体证据吗(回滚成本/合理疑问/被否决备选)?还是其中一条只写了"重要"这类空话?
3. 让阅读者回答:`scripts/check-adr-conditions.sh` 是否对本 ADR 的 frontmatter PASS?
4. 让阅读者回答:这个 ADR 取代了哪些旧 ADR?旧 ADR 是否只追加了 supersede 标记而决策正文未动?
5. 让阅读者回答:本次记录有没有越界写入 model.md / .debug/ / .code-review/ 产物?

## 不覆盖范围

- 不替代 **modeling-first**(活文档式领域建模)— ADR 是 point-in-time 决策快照,**归档不演进**;modeling-first 是 task 级活文档,持续迭代。同一议题可能两者都触发,但独立产出、独立生命周期,不双向同步(承载 `Rel.AdrRecorderSkill-ModelingFirstSkill` 与 `Invariant.Process.cross.5`)
- 不替代 **debugging**(运行时反馈环诊断)— 同一 PR 周期可分别触发,本 skill 不调用 debugging,debugging 也不强制升级到 adr-recorder(承载 `Rel.DebuggingSkill-AdrRecorderSkill`)
- 不替代 **thinking-guardrails**(编码前置思维守卫)— 写代码前的奥卡姆/建模思维不在本 skill 范围;adr-recorder 仅在"决策已发生"后启动
- 不替代 **code-review**(已写代码的结构性审查)— 模块层面的 deep / shallow / seam 判断在 code-review 的"抽象与边界"章节,不在 ADR 中
- 不负责"决策推演":三条件素材必须由调用方提供;若用户只说"我们也许该换数据库",本 skill 退回报错"决策未确定,先用 thinking-guardrails 或 modeling-first 推演"
- 不直接写跨会话记忆(`~/self-improving/`)— 仅 emit `AdrPublished` 事件,由宿主 coding agent 在后续触发 modeling-first 时消费
- 不强制"每个 ADR 必须关联 model 锚点":`related-model` 是可选字段;只有当本 ADR 直接回应某 model 的"已知歧义"slot 时才填

## 覆盖声明

无

## 引用资料

- `templates/adr.template.md`(ADR 单条最小骨架,frontmatter 三条件字段 + 五节正文 + supersede 占位)
- `scripts/check-adr-conditions.sh`(三条件 AND gate 机械校验脚本,含 `--self-test`,`set -euo pipefail`)
- `references/three-condition-gate.md`(三条件具体判断细则:难逆转的回滚成本量化、"会惊讶"的反例、真实取舍的备选 ≥ 2 阈值由来)
