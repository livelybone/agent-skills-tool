---
name: debugging
description: "运行时 bug 5 步反馈环诊断,落 repro 或回归测试。触发词:debug, 调试, 诊断, 复现, repro, feedback loop, 反馈环"
metadata:
  version: 0.1.0
  tags:
    - debugging
    - feedback-loop
    - repro
    - regression
---

# Debugging

把"运行时已观察到异常"的 bug 收敛成可复现 → 可定位 → 可修复 → 可回归的反馈环。本 skill 是**运行时事后**诊断流程,不是编码前置思维守卫(那是 thinking-guardrails),不是结构性审查(那是 code-review),不替代跨会话经验沉淀(self-improving 自行检测)。

## 适用场景

- 用户/CI 报告了一个具体的运行时异常,但当前不能稳定复现
- 已有 bug 报告但根因未定位,需要把"凭印象修"约束成"基于反馈环修"
- 修复一个 bug 时需要确保不再回归(必须落回归测试)
- CI failure 的根因定位:从失败日志反推到最小复现脚本

不适用:写新代码前的设计取舍(用 thinking-guardrails)、PR 已写完的结构性审查(用 code-review)、跨会话经验沉淀(由 self-improving 自动捕获)。

## 必须材料

- **bug 报告**:至少包含"观察到的现象 + 期望行为 + 一个触发样本(输入/操作/环境片段)"。无样本时第一步就是补样本。
- **可访问代码与运行环境**:能在本地或容器里执行触发路径(无环境则不进入流程,改走"环境复原"前置任务)
- **repro 资源占位**:`.debug/<bug-id>/` 目录用于存放本次诊断的临时产物(假设/插桩快照/决策日志);`bug-id` 由调用方提供,不存在则按 `YYYYMMDD-<short-slug>` 生成
- **回归测试承载位置**:项目原有测试目录(优先);若项目无测试基础设施,落 `.debug/<bug-id>/repro.sh` 作为最低回归脚本
- **(可选) 上游 ADR / 模型文件**:仅当 bug 涉及"已发布的不可逆决策被违反"时引用,debugging 本身不产 ADR

## 执行步骤

5 步顺序硬约束:**禁止跳过 reproduce 直接进入 fix**(承载 `Invariant.DebuggingSkill.2`)。每步定义"输入 → 动作 → 输出 → 进入下一步的 gate"。

### 1. Reproduce(强制工件)

- **输入**:bug 报告 + 一个触发样本
- **动作**:把现象压缩成一段可重复执行的命令/脚本/测试用例,目标是"裸跑 < 30s 且确定性命中失败 > 90%"(完整判断规则见 `references/feedback-loop-gate.md`)
- **输出**(强制):`.debug/<bug-id>/repro.sh`(可由 `templates/repro-script.template.sh` 拷贝得到)或项目内的失败测试用例(任一即可,优先测试用例);若现象只在概率上出现,记录命中率与触发样本数
- **进入下一步的 gate**:连续 3 次执行该 repro,失败模式一致(报错信息/退出码/断言定位 hash 相同)。**未通过 gate 不允许进入 hypothesise。**

### 2. Hypothesise(流程节点)

- **输入**:稳定 repro + 失败模式快照
- **动作**:列出 ≤ 3 条候选根因假设,每条标"如何被 repro 区分/证伪"。禁止"凭印象选一条直接进 instrument"
- **输出**:`.debug/<bug-id>/decision-log.md` 追加一条 Hypothesis 块(模板见 `templates/decision-log.entry.md`)
- **进入下一步的 gate**:每条假设有显式证伪策略

### 3. Instrument(流程节点)

- **输入**:候选假设清单
- **动作**:为最高优先级假设加最小插桩(日志/断点/printf/profile 采样),复跑 repro 收集观测;插桩不能改变行为(只读)
- **输出**:`.debug/<bug-id>/decision-log.md` 追加 Observation 块(模板见 `templates/decision-log.entry.md`),记录"哪条假设被区分/证伪/留存"
- **进入下一步的 gate**:至少一条假设被证伪或被观测确认

### 4. Fix(流程节点)

- **输入**:被观测确认的假设
- **动作**:写最小修复(改动范围限定在被确认的根因路径);**修复后立即重跑 repro,期望从"失败"变"成功"**
- **输出**:代码改动 + `.debug/<bug-id>/decision-log.md` 追加 Fix 块(模板见 `templates/decision-log.entry.md`),记录改动文件与判断依据
- **进入下一步的 gate**:repro 在修复前失败、修复后成功(差分必须可被外部验证,不能仅凭"我跑了一下")

### 5. Regress(强制工件)

- **输入**:修复 commit + 步骤 1 的 repro
- **动作**:把 repro 升级为长期回归测试(若步骤 1 已是测试用例则原地保留;若是 `.sh` 则迁移到项目测试目录,若项目无测试基础设施则保留 `.sh` 并在 README/CHANGELOG 留指针)
- **输出**(强制):项目内回归测试文件 **或** `.debug/<bug-id>/repro.sh`(完成定义,承载 `Invariant.DebuggingSkill.1`);emit `ReflectionEligibleEvent`(见"产物与格式")
- **完成定义校验**:存在**至少一个回归承载文件**,且该文件在当前代码上 pass、在修复前 commit 上 fail(可由 CI 在后续触发时验证)

## 产物与格式

### `.debug/<bug-id>/repro.sh`(最低复现脚本)

最小骨架由 `templates/repro-script.template.sh` 提供。要求:

- < 30s 完成一次跑(超时则需把样本最小化)
- 确定性 > 90%(连续 3 次失败模式一致)
- 不依赖 `.debug/` 之外的临时文件;依赖 fixture 时把 fixture 也放进 `.debug/<bug-id>/`
- 必须 `set -euo pipefail`(模板默认含)
- 修复前期望非零退出码,修复后退出码 0(用于回归判定)

### `.debug/<bug-id>/decision-log.md`(Decision Log 条目)

每步追加一段,不覆盖历史。三类块的具体格式见 `templates/decision-log.entry.md`(Hypothesis / Observation / Fix)。

### `ReflectionEligibleEvent`(发给 self-improving 的契约,via host steering)

最小 schema:

```json
{
  "bug-id": "<string,required,与目录名一致>",
  "repro-path": "<repo-relative path,required,如 .debug/20260503-foo/repro.sh 或 tests/regress/test_foo.py>",
  "fix-summary": "<string,required,一句话:根因 + 改动范围>",
  "session-id": "<optional,host 注入>"
}
```

字段语义:

- `bug-id` / `repro-path` / `fix-summary` 三字段为 **required**——任一缺失或为空字符串则 **不发出事件**;debugging 不直接写 `~/self-improving/`,只 emit 事件
- `session-id` 为 optional,由 host 注入
- 由宿主 coding agent 在后续触发 self-improving 时消费(承载 `Rel.DebuggingSkill-SelfImprovingSkill` 的 event 契约)
- 序列化格式与 host steering 接入点延到 self-improving 集成时定

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"

### 本 skill 特定检查

- [ ] **反馈环 gate**:`.debug/<bug-id>/repro.sh`(或对应测试用例)裸跑 < 30s,连续 3 次失败模式一致(确定性 > 90%);未达标则回到步骤 1 缩小样本(详细判断规则见 `references/feedback-loop-gate.md`)
- [ ] **5 步顺序**:`decision-log.md` 中 Hypothesis 块的时间戳 > Reproduce 完成,Fix 块的时间戳 > Observation 块(机械可校验:先后顺序;承载 `Invariant.DebuggingSkill.2`)
- [ ] **完成定义**:存在 `.debug/<bug-id>/repro.sh` 或项目测试目录下的回归测试,二者**至少一个被 commit**(承载 `Invariant.DebuggingSkill.1`)
- [ ] **触发词不越界**:本 skill 触发词不包含 thinking-guardrails / code-review / adr-recorder / modeling-first 已用词(承载 `Invariant.Process.cross.1`)
- [ ] **产物路径不越界**:只写 `.debug/<bug-id>/` 与项目测试目录;**禁止写** `docs/adr/`、`docs/models/`、`.code-review/`、`~/self-improving/`(承载 `Invariant.Process.cross.2` / `Invariant.Process.cross.3`)
- [ ] **边界互斥**:本 SKILL.md 不得在执行步骤中引入"建模思维 / 奥卡姆剃刀 / 写代码前检查清单"等编码前置语义——本 skill 是**运行时事后诊断**,不替代编码前置守卫(承载 `Invariant.Process.cross.4`)

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定验证

1. 让阅读者回答:这次 debugging 的 bug-id 是什么?repro 文件路径是什么?——指不出即未闭环
2. 让阅读者回答:5 步是否每步都有产物或日志条目?reproduce 与 regress 是否各有强制工件?
3. 让阅读者回答:repro 在"修复前失败、修复后成功"是否被外部验证(不是凭口头)?
4. 让阅读者回答:回归测试落到了哪个文件?CI 是否能拾取?
5. 让阅读者回答:本次诊断有没有越界写入 ADR/模型/code-review 产物?

## 反模式合集

> 本节用 ✗/✓ 对照列出**使用本 skill 时**容易出错的方式。LLM 对反例敏感度高于正例——单纯说"应该 X"不如说"不要 Y，因为 Z"。

✗ **跳过 reproduce 直接 fix**（"看错误信息感觉知道哪里坏，直接改"）
为什么错：没有稳定 repro 就 fix，无法区分"修了根因"vs"改了无关代码碰巧让现象消失"。
✓ 必须先有稳定 repro（< 30s, > 90% 命中），再进 hypothesise。承载 `Invariant.DebuggingSkill.2`。

✗ **凭印象选一个根因假设直接 instrument**
为什么错：单假设没有"被证伪策略"，instrument 即使观测到任何东西都没有 differential 能力（不知道是确认还是巧合）。
✓ 列 ≤ 3 候选假设，每条显式标"如何被 repro 区分/证伪"。

✗ **fix 后没重跑 repro 就 commit**
为什么错："我看代码改对了"不是验证。修复路径上还可能有别的失败模式残留。
✓ 修复前 repro fail → 修复后 repro pass，是步骤 4 的 gate（差分必须可被外部验证）。

✗ **不落回归测试，只在 decision-log 记"已修"**
为什么错：下次同类 bug 再出现时无法机械 catch，等于没修过。
✓ 步骤 5 强制——repro.sh 升级成长期回归测试，或保留 `.sh` 作为最低承载。

✗ **越界写 ADR / 模型 / code-review 产物**
为什么错：本 skill 是运行时事后诊断，不是建模/设计/审查。混淆边界后下次维护找不到对应文件。
✓ 只写 `.debug/<bug-id>/` 与项目测试目录；ADR 升级判断由用户决定（承载 `Invariant.Process.cross.2/3`）。

## 不覆盖范围

- 不替代 **thinking-guardrails**(编码前置思维守卫,常驻指令文件)— 本 skill 仅在"运行时已观察到异常"后启动,**不是**写代码前的检查清单(承载 `Invariant.Process.cross.4`)
- 不替代 **code-review**(已写代码的结构性审查)— 同一 PR 周期可分别触发,本 skill 不调用 code-review
- 不替代 **adr-recorder**(架构决策记录)— bug 修复中可能产生"换底层库"等决定,由用户判断是否升级到 adr-recorder,debugging 不强制
- 不直接写跨会话记忆(`~/self-improving/`)— 仅 emit `ReflectionEligibleEvent`,由宿主 coding agent 在后续触发 self-improving 时消费
- 不负责"环境复原":若 repro 环境缺失,本 skill 退回报错"无法进入 reproduce 步骤",由用户先恢复环境
- 不强制"hypothesise/instrument/fix 三步各产独立文件":三者通过 `decision-log.md` 内联记录;独立文件仅在"reproduce(repro 脚本)"和"regress(回归测试)"两端强制

## 覆盖声明

无

## 引用资料

- `templates/repro-script.template.sh`(repro 脚本最低骨架,含 `set -euo pipefail` 与 bug-id 占位 + 退出码语义)
- `templates/decision-log.entry.md`(Decision Log 三类块模板:Hypothesis / Observation / Fix)
- `references/feedback-loop-gate.md`(反馈环 gate 的具体判断规则:`< 30s` 与 `> 90%` 阈值的来源、连续 3 次校验方法、未达标处置流程)
