---
name: multi-agent-loop
description: 通过文件协议协调 coding agent（Claude、Codex、Crush、OpenCode）在有界循环中完成 review、discussion、verification 等结构化审查任务。
metadata:
  version: 3.0.0
---

# 适用场景

- 需要让一个 coding agent 调用另一个 coding agent 做 review、discussion、verification 等结构化审查任务
- 需要在独立视角下多轮迭代，但不想把长日志直接灌进当前会话上下文
- 需要有界循环，最多跑固定轮数，再由 controller 或用户裁决
- 支持以下 runner：`claude`、`codex`、`crush`、`opencode`，可自由组合（例如 `Claude → Crush`、`Claude → OpenCode`）

# 核心概念

- **controller**：发起循环、读取 agent 结论、逐条裁决的角色（通常是当前会话里的 Claude Code）。不执行任务本身，只指挥和裁决。
- **agent**：被 controller 拉起、执行具体任务、把结构化发现写入 `agent-output.md` 的子进程。当前 canonical prompt 协议覆盖 `review`、`discussion`、`verification` 这类结构化审查任务。只报告观察到的事实和无法判断的点，不做裁决。
- **关键澄清**：这里的"agent 调用 agent"是通过 CLI 子进程 + 文件协议完成的，不是模型内部原生互调。`claude -p` 与 `codex exec` 均作为独立子进程运行，输出不会污染 controller 的上下文。
- **跨轮任务一致性**：`agent-task.md` 在 setup 阶段一次性生成，之后所有轮次共享同一份文件。每一轮 agent 对**当前仓库状态**执行**同一个任务**，不感知上一轮的存在。保证分两层：(a) 流程层——`run_agent.sh` 不提供写 `agent-task.md` 的代码路径，正常流程中不会被触发修改；(b) 约定层——controller 按规程不在循环内修改该文件，若需调整任务语义，正当做法是终止当前循环、清理 `<task-name>/` 目录、重新 setup。**已知局限**：手工（controller/用户）直接改写 `agent-task.md` 只要仍符合模板契约，`validate_task.sh` 与 `run_agent.sh` 都会放行——skill 不做 hash/mtime 防篡改。如需更严格保证请在外层 CI/权限层面自备门禁。

# 必须材料

- 当前环境至少安装一个可无头执行的 agent CLI：`codex`、`claude`、`crush` 或 `opencode`
- `$SKILL_DIR/scripts/run_agent.sh`（`$SKILL_DIR` 指本 skill 的安装目录，即包含此 `SKILL.md` 的目录）
- `$SKILL_DIR/scripts/validate_task.sh` + `$SKILL_DIR/scripts/prompt_protocol.sh`（合成自检与 runner 协议校验共享）
- `$SKILL_DIR/templates/agent-prompt.txt`（合成 `agent-task.md` 的模板源文件）
- 每个审查任务使用唯一的 `<task-name>`，工作目录为 `$WORKDIR/.agent-loop/<task-name>/`；同一个任务的多轮次通过 `r1/`、`r2/`、`r3/` 子目录隔离
- `run_agent.sh` 首次运行会自动将 `.agent-loop/` 加入 `<workdir>/.git/info/exclude`，避免协议文件污染 agent 的仓库视图

# 工作目录结构

每个任务独占一个子目录，轮次产物按 `r<N>/` 分层：

```text
$WORKDIR/.agent-loop/
  <task-name>/
    agent-task.md          # setup 阶段一次性生成，跨轮共享只读
    r1/
      agent-status.txt     # 本轮状态：空(运行中) | done | error
      agent-output.md      # 本轮结构化发现
      agent.log            # 本轮原始输出，严禁读取（需用户明确授权）
      agent-judgment.md    # controller 对本轮 findings 的独立重评
    r2/
      agent-status.txt
      agent-output.md
      agent.log
      agent-judgment.md
    r3/ ...
```

`agent-task.md` 在 task-name 层（不在任何 `r<N>/` 下），物理上只有一份——跨轮任务一致性由此保证。

# 执行步骤

流程分成两阶段：**setup**（一次）与 **run**（每轮）。

## Setup 阶段（循环开始前，仅一次）

1. **确认 task-name**：选一个描述性的 `<step>-<module>` 名称（不再需要 `-r<N>` 后缀，轮次在子目录中体现）。例如 `scenario-review-auth`、`spec-review-inventory`。
2. **合成 `agent-task.md`**：controller 亲自读取 `templates/agent-prompt.txt` 与 task-module（可以是一个已有的 prompt 模块文件如 `skills/test-design-and-implementation/prompts/scenario-review.md`，也可以是用户当前会话里临时给出的一段文字），按「`agent-task.md` 合成契约」智能合成，写入 canonical 路径 `$WORKDIR/.agent-loop/<task-name>/agent-task.md`。
3. **自检**：`<SKILL_DIR绝对路径>/scripts/validate_task.sh <task-name> [workdir]`（`workdir` 省略时默认 `$PWD`，controller 的 cwd 不在目标 workdir 时必须显式传）。validator 通过后才能进入 run 阶段。

## Run 阶段（每轮）

4. **启动 agent**（按轮次递增调用）：
   - **通用命令**：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto <runner> <task-name> <round-number> <workdir>`
     - `<runner>` ∈ `codex | claude | crush | opencode`
     - `<round-number>` 是正整数；首轮传 `1`，第二轮传 `2`，以此类推
     - `run_agent.sh` 会自动校验 `agent-task.md` 存在并再次跑 validator（保证其仍符合模板契约；注意 validator 只校验结构与固定段，不能检测"保持合法但指令块被改写"的篡改——见「核心概念」中的已知局限）
   - **detach 模式**：
     - `--detach=auto`（推荐）：有 `tmux` 用独立 session，没 `tmux` 退化为同步阻塞
     - `--detach=tmux`：强制 tmux；宿主会清理后台子进程时用这个。stdout 返回 `detached:<session>`，`agent-status.txt` 在返回前以空文件预创建，controller 可立即轮询
     - `--detach=none` 或省略：同步阻塞；controller 如需非阻塞需自己后台化
   - **runner 差异**：
     - `codex`：`codex exec --sandbox danger-full-access`。macOS + Claude Code 环境下外层 Claude 还必须以 `dangerouslyDisableSandbox: true` 调用（详见「已知平台问题」）
     - `claude`：无平台限制
     - `crush` / `opencode`：通过各自 `run` 非交互模式执行，需预先配置 provider（opencode 支持内置免费模型）
   - **命令格式约束**：构造 Bash 命令时必须先将 `$SKILL_DIR` 解析为绝对路径字面量再拼接。禁止 `$SKILL_DIR/scripts/...` 变量引用或 `SKILL_DIR="..." $SKILL_DIR/scripts/...` 内联赋值——权限规则按字面量匹配。
5. **轮询等待 agent 完成**：agent 执行耗时因任务复杂度差异很大（数秒到数分钟均属正常），controller 需要耐心等待，通过定时轮询 `<task-name>/r<N>/agent-status.txt` 判断是否完成：
   - 轮询间隔：每 **30 秒** 检查一次
   - 超时上限：**10 分钟**；超时后视为 error，记录日志。超时属于步骤 7「阻塞型例外」（无法 best-effort 判断、且继续推进会让后续轮产物建立在不稳定基线上），此时 inline 告知用户即可
   - 判断逻辑：文件内容为 `done` → 成功完成；`error` → 失败（含 agent 异常退出 `TERM/HUP/INT`）；空 → 仍在运行。正常流程中 status 文件在所有 prelaunch 校验通过后立即创建（空文件），因此"文件不存在"不是合法的运行中状态——它意味着 runner 在 prelaunch 阶段被拒绝：参数校验失败 / prompt 协议校验失败 / 同轮次已有产物（覆盖拦截）/ 轮数超限 / judgment 缺失。例外：`--detach=tmux` 在外层返回前已预创建空 status 文件，prelaunch 失败会把该文件写成 `error`。无论哪种路径，controller 都应读 `run_agent.sh` 的 stderr 判断具体原因并修正；不要当作"仍在运行"继续轮询
   - 轮询期间 controller 不应做其他裁决动作，避免读到不完整的输出
   - **禁止使用 `agent.log` 推断运行状态**：不得通过 `wc -c`、`ls -la`、`tail` 等任何方式读取或探测 log 文件来判断 agent 是否仍在运行。唯一的状态判断来源是 `agent-status.txt`。status 为空说明 agent 仍在运行，继续等待即可
6. **只读取结构化文件**：
   - 允许读取：`<task-name>/r<N>/agent-output.md`
   - **严禁以任何方式访问 `agent.log`**——包括但不限于 `cat`、`head`、`tail`、`wc`、`ls -la`、`stat` 等读取内容或元数据的操作。除非用户明确授权（如调试失败时用户主动要求查看），读取前必须向用户确认
7. **controller 逐条裁决并写 `agent-judgment.md`**：**先写裁决，再修复，再判断是否下一轮**。这是协议强制门——`run_agent.sh` 在你启动下一轮时会扫描 `<task-name>/r*/`，任何已 `done` 的历史轮次缺少 `agent-judgment.md` 都会直接拒绝。
   - 读完 `<task-name>/r<N>/agent-output.md` 后，写 `<task-name>/r<N>/agent-judgment.md`，每条 finding 一行，格式：
     ```
     [<id>] agent:<Severity> → controller:<Severity>  reason: <一句话>
     ```
     `<id>` 可自拟（如 `F1`、`issue-1`），`<Severity>` ∈ `Critical | Major | Minor | Info`，理由用一句话说明为什么同意或降/升级
   - 然后对每条按裁决结果处理。**默认自动推进，不在轮次之间停下来向用户确认**——四种分支都属于"自动执行"，只有极少数"阻塞型"才 inline 暂停：
     - 真 Critical/Major 且明显正确 → 修复，**直接进入下一轮**（不等用户批准）
     - 被降为 Minor/Info → 不修、记录，直接进入下一轮
     - 明显错误或脱离上下文 → 拒绝，在 reason 里说明，直接进入下一轮
     - 涉及产品、架构、安全、权衡 → **默认**追加到循环级的"待用户裁决"累积清单 `$WORKDIR/.agent-loop/<task-name>/pending-user-decisions.md`（单文件、跨轮累积、每行一条，格式：`[r<N>/<finding-id>] <Severity> controller:<best-effort 判断> reason: <一句话>`），**继续下一轮不停顿**；仅当属于下面「阻塞型例外」时才 inline 暂停。此文件与每轮的 `agent-judgment.md` 分离，保持后者"一条 finding 一行"的格式纯度不被破坏
   - **严重度膨胀对抗**：agent 后期轮次易把"理论可构造"标成 Critical。controller 的 reason 里**必须**直面两个问题：
     - 这条 finding 在真实 LLM 自然合成路径里出现的概率大致是？
     - 修复成本（代码复杂度增量、维护成本）值不值？
   - **盲同意 = 失职**：如果你的 `controller:` 严重度和 `agent:` 完全一致，reason 必须写清楚独立验证了什么，而不是"同意 agent 评估"。
   - **阻塞型例外**（才允许 inline 向用户暂停确认）：同时满足以下两条才构成"阻塞"——
     1. controller 没有足够信息做出哪怕是"暂定决策，继续循环，事后复核"的 best-effort 判断（不是"我更愿意让用户拍"，而是"我 literally 不知道往哪走都是有理由的错")
     2. 继续推进带来不可逆后果（改动数据、irreversible 删除、生产级影响、安全风险实锤）
   - **反例澄清**（都**不**构成阻塞，必须自动裁决并推进）：
     - mechanical 修复（修法明确、后果局部、可回退）
     - 级别重评（agent Major → controller Info，理由写清即可）
     - 文档措辞调整、命名偏好、Streisand 级别的理论攻击
     - 你只是觉得"让用户看一眼更稳"——这是过度保守，不是真实阻塞
8. **有界循环**：每一轮在执行层面独立——agent 读取同一份 `agent-task.md`，对当前仓库状态执行同一个任务，不感知上一轮的存在。但 controller 的**调度决策**依赖本轮裁决结果来判断是否继续。
   - **先裁决后终止**：即使某轮表面上已经满足终止条件，controller 也必须先逐条裁决本轮发现，并对"明显正确且局部可执行"的问题先完成修复，再根据修复后的裁决结果判断继续/暂停/终止。禁止在未完成本轮裁决与可直接修复项处理前直接终止。
   - **裁决时重新评估严重度**：agent 的严重度标注仅供参考，controller 必须对每条发现独立判断实际严重度。后期轮次 agent 倾向于严重度膨胀（将 Minor 级问题标为 Major 以维持"仍有重要发现"的表象），controller 不得盲信。
   - **继续条件**：经 controller 重新评估后，本轮存在至少一条被裁决为 Major 及以上的发现（无论是否已修复）→ 修复后**必须**启动下一轮（`round-number + 1`），由新 agent 独立审查当前状态。**禁止以任何理由跳过验证轮**——包括但不限于"修复很简单"、"只是文档补充"、"不存在引入新问题的风险"、"可直接确认正确性"。这些都是 rationalization，不构成跳过验证的合法依据。
   - **暂停条件**（罕见，默认不走）：仅在步骤 7「阻塞型例外」两条同时成立时，inline 升级给用户裁决。其他"希望用户过目"的点全部归入"待用户裁决"累积清单，循环终止后一次性呈现。用户 inline 裁决完成后，controller 根据继续/终止条件决定是否启动下一轮。
   - **终止条件**（满足任一即停止）：
     - 达到最大 3 轮（`run_agent.sh` 拒绝 `<round-number>` > 3 的启动请求。gate 针对默认流程阻断无意识滑坡——`--allow-round-overflow` 可绕过，仅供调试与回归测试，日常流程不应依赖。正当做法是在 controller 层调整策略：拆分 scope、降低单轮深度、或 escalate 给用户）
     - 经 controller 重新评估后，本轮无 Major 及以上级别的发现（即使 agent 标注了 Major，controller 判定实质为 Minor 则视为无 Major）。**注意**：若本轮存在被裁决为真 Major 的发现并已修复，仍属"本轮有 Major"，必须走继续条件启动下一轮验证，不得视为终止
   - **终止后汇报**（强制）：循环达到终止条件后，controller **必须**向用户一次性汇报以下三项，**不得省略，也不得拆成多条对话节奏**：
     1. 每轮 `agent-judgment.md` 的浓缩摘要（agent 提了什么、controller 怎么判、为什么）
     2. 循环中实际做的代码/文档变更清单（文件 + 一句话目的）
     3. **待用户裁决清单**：步骤 7 中累积的产品/架构/安全/权衡项，每条附 controller 的 best-effort 判断和理由，让用户批量复核。清单为空也要明说"无待裁决项"
   - **反模式**（禁止）：在循环进行中为 mechanical 修复 / 级别重评 / 理论攻击降级等向用户反复确认"是否继续"、"要不要修"、"这样改对吗"——这些问题本身就是过度保守的信号，controller 的默认状态是"推进循环、汇总到终止后一次性呈现"
   - **关于"物理保证"的诚实声明**：本条约束（"默认不中途打断用户"）是 **convention-level**，skill 无法为此提供 script gate——controller ↔ user 的交互发生在 run_agent.sh 触及不到的上层。已有的 mechanical gates（judgment gate、round-cap gate、validator、写路径隔离）只能覆盖循环内部的文件流转。controller 的自律由三重文字约束承载（步骤 7 阻塞型例外 + 步骤 8 反模式 + 质量门槛"失职"定性），读者按字面读应当走向"默认推进"；仍违反者属于主动忽视规则，skill 无物理手段阻拦

## `agent-task.md` 合成契约

生成 prompt 不是机械替换，而是 controller（LLM 智能）对 `templates/agent-prompt.txt` 与 task-module 的一次**智能合成**。目标：把 task-module 里的任务语义精准落入模板的可变槽位，并保证模板的固定部分与协议约束丝毫不动。合成后必须能通过 `scripts/validate_task.sh` 校验。

**重要**：`agent-task.md` 在 setup 阶段一次性生成，**之后所有轮次共享这一份文件**。合成时不要假设这是"第一轮的任务"——它就是**整个循环的任务**，后续轮次的 agent 会针对修复后的仓库状态再次执行同一个任务。

### 可变槽位（controller 智能填写）

| 槽位 | 对应模板行 | 填写规则 |
|---|---|---|
| 类型 | `- 类型：<...>` | 从模板占位定义的允许集合里选一个值（当前：`review \| discussion \| verification`）。**循环开始后不得更换**——整份 `agent-task.md` 在循环中不可变 |
| 指令块 | `<在此描述具体任务>` | 由 task-module 蒸馏而来的任务指令。允许改写/合并/重排/删冗以保持简洁。**不得**在指令块里重新声明模板固定段（目标词：`硬性规则` / `观点级别定义` / `输出格式` / `严重度诚实原则`）——包括 ATX heading（任意 `#` 深度）、setext heading（`===` 或 `---` 下划线）、任意 markdown emphasis 变体（`*` / `_` 任意组合 + 可选空格）；判定会穿透 markdown 容器前缀：列表 `-` / `*` / `+`、带 `.` 或 `)` 的有序列表、checkbox `[x]` / `[ ]`、blockquote `>`、表格 `\| ... \|`（按单元拆开检测），以及这些的嵌套组合。**也不得**把 severity 四档齐全写进来——判定穿透同样的容器前缀，容忍反引号/方括号/强调包裹与半角/全角冒号。可以只引用其中一两档作为上下文解释，但四档齐全即拒。**代码块豁免**：fenced code block（` ``` ` / `~~~`，closer 需同字符类型且长度 ≥ opener；未闭合则整份拒）与 4 空格缩进的 indented code block 都被视为样例 prose，不触发上述检测。**例外**：4 空格缩进行若去掉缩进后以列表 / blockquote / checkbox / 有序列表 / 表格（`\|` 开头）标记起头，视为"列表/表格的缩进续行"而非 indented code block，仍走上述启发式检测（防止用缩进伪装绕过） |
| 严重度定义块 | `<严重度定义块>` | 四行 `` - `[Level]`：<含义> ``，按 **Critical → Major → Minor → Info** 顺序，每行 body 非空（validator 只校验这一层结构）。含义文本**应**给出可观察的分级维度（如"LLM 自然合成里每百条出现 N 次"、"阻断合法用户 vs 仅误伤低频 case"、"需要刻意构造 vs 常见自然写法"），**避免**只用"显著/明显/轻微/少量"这种主观形容词——主观形容词会让审查 agent 把所有理论可达问题都标 Critical，触发严重度膨胀。此条由 controller 合成时自律遵守，validator 不做语义检查。若 task-module 已有 severity 语义（如 `## 严重度`、`## 严重度标注`），抽出后按这个要求再校准一次；若 task-module 无语义，用下文「默认级别定义」作为 fallback |

### 固定槽位（逐字保留，不得改动）

- `# 硬性规则` 段的 1–8 条全部
- `**严重度诚实原则**` 段
- `# 输出格式` 段（章节标题、例行项、例子占位全部保留）
- 所有章节标题、空行、非占位的注释文本

> 任何对固定槽位的改写——**包括**改标题、改编号、新增或删除一条硬性规则、修改输出格式的占位示例——都会被 validator 逐字拒绝。此外，validator 也会拒绝指令块里**重新声明**这些固定段（详见可变槽位表对"指令块"的约束）。

### 合成纪律

- **蒸馏而非搬运**：task-module 里可能有任务描述、输入输出、审查项、审查原则、原则示例等。把真正对 agent 行动有约束力的内容提炼到指令块；不要把整个文档首尾复制
- **消除冗余**：如果 task-module 里有 `## 严重度 / ## 严重度标注 / ## 级别定义` 这类小节，内容**应**被提升到 `<严重度定义块>` 槽位，而不是同时出现在指令块和观点级别定义两处
- **保留意图**：在不破坏原作者意图的前提下可改写措辞；若某条规则的文本本身已有授权意义（例如引用了外部文档路径），照抄，不要自行重述
- **不要假装更聪明**：task-module 没覆盖到的部分，不要凭空补充规则；不确定就放到"无法判断的点"——后续由 controller 按步骤 7 分流（自动推进或累积到待用户裁决清单）

### 自检流程

1. 写入 `$WORKDIR/.agent-loop/<task-name>/agent-task.md`
2. `<SKILL_DIR绝对路径>/scripts/validate_task.sh <task-name> [workdir]`（`workdir` 省略时默认 `$PWD`；cwd 不在目标 workdir 时必须显式传）
3. 若 validator 报错：读错误信息 → 修正同一文件 → 重新 validate（此时仍未产生 agent 运行产物）
4. 通过后才能进入 run 阶段（步骤 4 起）

### 观点级别类型的不变性

`Critical / Major / Minor / Info` 四档**作为类型**是协议不变量；合成过程不得增删档位，也不得改名。每一档的**具体含义**可以按任务特化（这就是智能合成的价值）——例如 scenario 审查的 Critical 是"场景越界让后续测试建立在错误边界上"，code review 的 Critical 是"功能错误/安全漏洞"。

默认级别定义如下（适用于大部分通用 code review / 文档审查任务）：
- `[Critical]`：功能错误、安全漏洞、数据损坏风险；必须修复并在下一轮验证
- `[Major]`：显著质量问题（性能、可维护性、API 误用）；必须修复并在下一轮验证
- `[Minor]`：风格、文档、可读性问题；可选修复
- `[Info]`：纯观察或背景说明，无需动作

task-module 有自己的 severity 语义时，优先使用 task-module 的（比如 scenario-review.md、plan-review.md 等的 `## 严重度` 小节）；task-module 无 severity 语义时，结合默认级别定义生成合理的级别定义（实在无法确定时，建议直接使用默认级别定义）。

## controller 裁决与 judgment 文件

控制严重度膨胀的核心机制：每次 agent 完成后，controller **必须**写对应轮次的 `agent-judgment.md`，对每条 finding 独立再评估，再决定修/不修/下一轮。

### 文件位置与格式

`$WORKDIR/.agent-loop/<task-name>/r<N>/agent-judgment.md`，纯文本，每条 finding 一行：

```
[<id>] agent:<Severity> → controller:<Severity>  reason: <一句话独立判断依据>
```

- `<id>`：自拟（`F1`、`bypass-ghm` 之类），与对应 `agent-output.md` 中的 finding 对应即可
- `<Severity>`：`Critical | Major | Minor | Info` 其中之一
- `reason`：不允许只写"同意 agent"；必须说明独立验证了什么、或为何降/升级、或为何此路径不算"自然合成"

一个示例（`r1/agent-judgment.md`）：

```
[F1] agent:Critical → controller:Major  reason: CRLF 行尾在 Windows 编辑器常见，阻断合法用户；改一行 mapfile 后置处理即可
[F2] agent:Critical → controller:Minor  reason: 需要 30+ 字符中文注释才能触发，合成纪律要求蒸馏、不会自然写出这么长
[F3] agent:Critical → controller:Minor  reason: emoji 前缀伪装重述，合成契约已禁止指令块装饰化；修复成本高于收益
```

### run_agent.sh 的强制门

当你调用 `run_agent.sh` 启动**下一轮**时，脚本会扫描 `$WORKDIR/.agent-loop/<task-name>/r*/`，对每个已 `done` 但缺少 `agent-judgment.md` 的历史轮次 → **拒绝启动**，列出缺失路径。判定规则：
- `r<K>/agent-status.txt == "done"` 且 `r<K>/agent-output.md` 存在 → 必须有 `r<K>/agent-judgment.md`
- 当前轮 `r<N>/` 自身不计入检查（允许清理后同轮重试）

使用 `--skip-judgment-check` 可绕过（仅用于历史目录清理、自动化测试等）。日常流程不应使用。

### 与继续/终止条件的关系

步骤 8 的"继续条件"**在 controller 重评后生效**：本轮 `agent-judgment.md` 里没有 `controller:` 标为 Major 及以上的 finding → 无论 agent 标了多少 Critical，本轮都视为无真 Major → 可以终止。

## `agent-output.md` 推荐格式

```md
## 发现 / 变更

- [Critical] [文件:行号 或 模块名] 具体描述
- [Major] [文件:行号 或 模块名] 具体描述
- [Minor] [文件:行号 或 模块名] 具体描述
- [Info] [文件:行号 或 模块名] 具体描述

## 依据

- 对应上方每条发现的支撑证据，保持一一对应

## 无法判断的点

- 需要产品知识、架构背景或更多上下文才能确定的点；若无则写"无"
```

# 质量门槛（controller 约束）

- 必须区分 `controller` 与 `agent`——controller 不执行任务，只指挥和裁决；不得宣称"agent 原生互调"，准确表述为"controller 通过 CLI 子进程启动 agent"
- **循环中默认自动推进**：mechanical 修复、级别重评、理论攻击降级等都由 controller 当场裁决、落 judgment、继续下一轮，**不得**为这些向用户反复确认。只有满足步骤 7「阻塞型例外」两条才允许 inline 暂停。"让用户过目更稳"是过度保守，不是合法暂停理由。违反此条即为过度打断用户节奏，等同于失职
- `agent-task.md` 在 setup 阶段一次性生成，循环开始后禁止修改——跨轮任务一致性由此保证。若发现合成时有瑕疵需要修复，应当终止当前循环、清理 `<task-name>/` 目录、重新 setup（而不是中途改 prompt）
- 每个审查任务使用唯一 task-name，禁止多任务共用同一 `<task-name>/` 目录
- 必须限制循环轮数，禁止无界自反馈；inline 升级条件限定为步骤 7「阻塞型例外」两条同时成立；其他产品/架构/安全/权衡议题走"待用户裁决"累积清单，终止后一次性汇报
- controller 只通过文件读取 **agent 子进程**的结构化输出，不内联读取 agent 的 stdout/stderr；`run_agent.sh` 壳脚本自身的 stderr 可以读，用于排查 prelaunch 阶段被拒原因（参数、协议、轮数、judgment、覆盖拦截）
- controller 裁决时必须独立判断严重度，不得直接采信 agent 标注——已知退化模式：后期轮次 agent 将 Minor 膨胀为 Major、将"修复未传播"包装为新发现
- controller 必须先完成本轮裁决与可直接修复项处理，再判断是否终止；不得因"表面满足终止条件"而提前停在未裁决状态
- setup 阶段合成 `agent-task.md` 后必须先通过 `scripts/validate_task.sh` 自检；自检通过后才能调用 `run_agent.sh`。不得绕过 validator 直接启动 runner
- controller 每次 agent 完成后必须写 `r<N>/agent-judgment.md` 再进入修复/下一轮（格式、gate 机制、反盲同意要求详见步骤 7 与「controller 裁决与 judgment 文件」章节）
- task-module 的「观点级别定义」应包含可观察的分级维度（如"LLM 自然合成出现频率"、"是否阻断下游"），避免只用"显著/明显/轻微/少量"这种主观形容词——主观定义会直接诱发审查 agent 的严重度膨胀。此条是 controller 合成时的自律约束，validator 不做语义检查

# 验证方式

最小验证：

1. **runner 矩阵**：对当前环境**已安装的每个** runner（`{codex, claude, crush, opencode}` 的非空子集，至少一个）各用一个独立 task-name，完整跑 setup → r1 → judgment → r2 的最小循环，确认 `agent-task.md` 只被写入一次、每轮在独立 `r<N>/` 子目录产生 `agent-output.md` / `agent.log` / `agent-status.txt`。未安装的 runner 跳过即可，不是验证失败
2. **并行隔离**：多个 task-name 并行不冲突
3. **git exclude**：首次运行后 `.agent-loop/` 已被写入 `<repo>/.git/info/exclude`
4. **validator**：按合成契约手写一份 `agent-task.md`，`scripts/validate_task.sh <task-name>` 通过；再分别制造缺陷（改坏固定章节文本、类型越界、severity 缺级 / 乱序 / body 为空、canonical prompt 换 symlink），确认 validator 给出明确错误并拒绝
5. **judgment gate**：让 r1 跑完产出 `agent-output.md` + `agent-status.txt == done`，**不写** `r1/agent-judgment.md`，尝试用同 task-name 启动 r2 应被 `run_agent.sh` 拒绝（错误信息列出缺失的 `r1/agent-judgment.md` 路径）；写入后重试应通过。`--skip-judgment-check` 能绕过（仅用于历史清理/测试）
6. **round-cap gate**：尝试传 `<round-number>` = 4 启动，应被 `run_agent.sh` 拒绝；加 `--allow-round-overflow` 能绕过（仅用于调试）
7. **覆盖拦截**：同一 `r<N>/` 下已有产物时再次启动同轮应被拒绝（避免静默覆盖）

# 已知平台问题

| 平台                        | Runner     | 问题                                                                                                                   | 应对                                                                                                                        |
| --------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| macOS + Claude Code sandbox | `codex`    | Claude Code sandbox 阻止访问 macOS `SCDynamicStore` 系统守护进程，导致 Codex CLI 的 `system-configuration` crate panic | controller 启动 `codex` agent 时必须禁用 sandbox（`dangerouslyDisableSandbox: true`），或改用 `claude` runner（不受此影响） |
| macOS + Claude Code sandbox | `crush`    | **未验证**：Crush 基于 Go，可能触发类似系统调用限制                                                                     | 优先尝试 sandbox 内运行；若失败则 `dangerouslyDisableSandbox: true`                                                         |
| macOS + Claude Code sandbox | `opencode` | **未验证**：OpenCode 基于 Node.js，可能触发类似限制                                                                     | 同上                                                                                                                        |
| 任意                        | `crush`    | `crush run` + tool calling（文件写入等）存在[已知 bug](https://github.com/charmbracelet/crush/issues/1322)              | 仅用于 review/discussion/verification 等只读任务                                                                               |

# 不覆盖范围

- 不负责绕过宿主平台的权限模型
- 不保证所有 agent CLI 支持相同的工具权限和工作目录语义
- 不负责跨机器调度、队列或真正的分布式编排
- 不提供"peer / 第二视角"机制——多视角需求请分别拉 task-name 独立跑，再由 controller 合并结论

# 引用资料

- `$SKILL_DIR/scripts/run_agent.sh` — runner 包装脚本，controller 通过它启动 agent（推荐用 `--detach=auto` 让脚本自行决定是否脱离）。启动前会调用 validator 二次校验 `agent-task.md`
- `$SKILL_DIR/scripts/validate_task.sh` — controller 合成 `agent-task.md` 后的自检入口；传入 `<task-name> [workdir]`，失败时给出精确错误信息，controller 据此修正再次校验
- `$SKILL_DIR/scripts/prompt_protocol.sh` — validator 与 runner 共享的模板协议解析与校验逻辑；负责模板加载、固定槽位逐字比对、severity 四行校验
- `$SKILL_DIR/templates/agent-prompt.txt` — controller 合成 `agent-task.md` 时的模板源文件，包含所有固定槽位与占位
- 本机 CLI 自检：`codex exec --help`
- 本机 CLI 自检：`claude --help`
- 本机 CLI 自检：`crush run --help`
- 本机 CLI 自检：`opencode run --help`
