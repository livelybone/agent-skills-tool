---
name: multi-agent-loop
description: 通过文件协议协调多个 coding agent（Claude、Codex、Crush、OpenCode）在有界循环中完成 review、discussion、verification 等结构化审查任务。
metadata:
  version: 2.2.0
---

# 适用场景

- 需要让一个 coding agent 调用另一个 coding agent 做 review、discussion、verification 等结构化审查任务
- 需要多个独立视角，但不想把长日志直接灌进当前会话上下文
- 需要有界循环，最多跑固定轮数，再由 controller 或用户裁决
- 支持以下 runner：`claude`、`codex`、`crush`、`opencode`，可自由组合拓扑（如 `Claude → Crush`、`Claude → OpenCode` 等）

# 核心概念

- **controller**：发起循环、读取 agent 结论、逐条裁决的角色（通常是当前会话里的 Claude Code）。不执行任务本身，只指挥和裁决。
- **agent（主）**：被 controller 拉起、执行具体任务、把结构化发现写入 `agent-output.md` 的子进程。当前 canonical prompt 协议覆盖 `review`、`discussion`、`verification` 这类结构化审查任务。只报告观察到的事实和无法判断的点，不做裁决。
- **peer（副，可选）**：在 agent 已产出 `agent-output.md` 的前提下，读取该产出并提出独立意见（支持、质疑或补充），写入 `peer-output.md`。peer 是对 agent 结论的第二视角挑战，不是独立执行任务的角色。peer 同样只输出观点，不做裁决。
- **角色选择原则**：需要执行一项任务（含审查）→ 用 agent；需要挑战 agent 已有结论 → 用 peer。审查已有产物（如 review Spec、review Test）属于"执行审查任务"，应使用 agent 角色而非 peer。
- **关键澄清**：这里的"agent 调用 agent"是通过 CLI 子进程 + 文件协议完成的，不是模型内部原生互调。`claude -p` 与 `codex exec` 均作为独立子进程运行，输出不会污染 controller 的上下文。

# 必须材料
judgement
- 当前环境至少安装一个可无头执行的 agent CLI：`codex`、`claude`、`crush` 或 `opencode`
- `$SKILL_DIR/scripts/run_agent.sh`（`$SKILL_DIR` 指本 skill 的安装目录，即包含此 `SKILL.md` 的目录）
- `$SKILL_DIR/scripts/validate_task.sh` + `$SKILL_DIR/scripts/prompt_protocol.sh`（合成自检与 runner 协议校验共享）
- `$SKILL_DIR/templates/agent-prompt.txt`（合成 `agent-task.md` / `peer-task.md` 的模板源文件）
- 每一轮执行都必须有唯一的任务名（task-name），用于隔离工作目录；禁止把不同轮次复用到同一个 task-name
- `run_agent.sh` 首次运行会自动将 `.agent-loop/` 加入 `<workdir>/.git/info/exclude`，避免协议文件污染 agent 的仓库视图

# 执行步骤

1. **确认拓扑**：明确谁是 controller，谁是 agent，是否需要 peer。
2. **选定任务名**：每一轮执行都使用唯一的 `<task-name>`，工作目录为 `$WORKDIR/.agent-loop/<task-name>/`，多任务并行不冲突。推荐命名：`<step>-<module>-r1`、`<step>-<module>-r2`……（runner 会拒绝复用已存在同角色产物的 task-name，看到该错误时新建下一轮目录，不要重试覆盖）
3. **合成本轮任务**：controller 亲自读取 `templates/agent-prompt.txt` 与 task-module（可以是一个已有的 prompt 模块文件如 `skills/test-design-and-implementation/prompts/scenario-review.md`，也可以是用户当前会话里临时给出的一段文字），按「`agent-task.md` / `peer-task.md` 合成契约」智能合成本轮 prompt，写入 canonical 路径 `$WORKDIR/.agent-loop/<task-name>/agent-task.md`（peer 写 `peer-task.md`）。写完后**必须**先用 `<SKILL_DIR绝对路径>/scripts/validate_task.sh <task-name> <role> [workdir]` 自检（`workdir` 省略时默认为 `$PWD`，controller 的 cwd 不在目标 workdir 时必须显式传）；validator 通过后再进入步骤 4。契约细节见下文「`agent-task.md` / `peer-task.md` 合成契约」。
4. **启动 agent**：
   - **通用命令**：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto <runner> <task-name> <agent-task.md路径> agent <workdir>`
     - `<runner>` ∈ `codex | claude | crush | opencode`
     - `<agent-task.md路径>` 必须是 canonical 路径 `<workdir>/.agent-loop/<task-name>/agent-task.md`
   - **detach 模式**：
     - `--detach=auto`（推荐）：有 `tmux` 用独立 session，没 `tmux` 退化为同步阻塞
     - `--detach=tmux`：强制 tmux；宿主会清理后台子进程时用这个。stdout 返回 `detached:<session>`，`*-status.txt` 在返回前以空文件预创建，controller 可立即轮询
     - `--detach=none` 或省略：同步阻塞；controller 如需非阻塞需自己后台化
   - **runner 差异**：
     - `codex`：`codex exec --sandbox danger-full-access`。macOS + Claude Code 环境下外层 Claude 还必须以 `dangerouslyDisableSandbox: true` 调用（详见「已知平台问题」）
     - `claude`：无平台限制
     - `crush` / `opencode`：通过各自 `run` 非交互模式执行，需预先配置 provider（opencode 支持内置免费模型）
   - **命令格式约束**：构造 Bash 命令时必须先将 `$SKILL_DIR` 解析为绝对路径字面量再拼接。禁止 `$SKILL_DIR/scripts/...` 变量引用或 `SKILL_DIR="..." $SKILL_DIR/scripts/...` 内联赋值——权限规则按字面量匹配
5. **轮询等待 agent 完成**：agent 执行耗时因任务复杂度差异很大（数秒到数分钟均属正常），controller 需要耐心等待，通过定时轮询 `*-status.txt` 判断是否完成：
   - 轮询间隔：每 **30 秒** 检查一次 `agent-status.txt`（或 `peer-status.txt`）
   - 超时上限：**10 分钟**；超时后视为 error，记录日志并升级给用户
   - 判断逻辑：文件内容为 `done` → 成功完成；`error` → 失败（含 agent 异常退出 `TERM/HUP/INT`）；空 → 仍在运行。正常流程中 status 文件在所有 prelaunch 校验通过后立即创建（空文件），因此"文件不存在"不是合法的运行中状态——它意味着 runner 在 prelaunch 阶段被拒绝：参数校验失败 / prompt 协议校验失败 / 同角色产物已存在（复用拦截）。例外：`--detach=tmux` 在外层返回前已预创建空 status 文件，prelaunch 失败会把该文件写成 `error`。无论哪种路径，controller 都应读 `run_agent.sh` 的 stderr 判断具体原因并修正；不要当作"仍在运行"继续轮询
   - 轮询期间 controller 不应做其他裁决动作，避免读到不完整的输出
   - **禁止使用 `agent.log` / `peer.log` 推断运行状态**：不得通过 `wc -c`、`ls -la`、`tail` 等任何方式读取或探测 log 文件来判断 agent 是否仍在运行。唯一的状态判断来源是 `*-status.txt`。status 为空说明 agent 仍在运行，继续等待即可
6. **只读取结构化文件**：
   - 允许读取：`agent-output.md`、`peer-output.md`（如有 peer）
   - **严禁以任何方式访问 `agent.log`、`peer.log`**——包括但不限于 `cat`、`head`、`tail`、`wc`、`ls -la`、`stat` 等读取内容或元数据的操作。除非用户明确授权（如调试失败时用户主动要求查看），读取前必须向用户确认
7. **controller 逐条裁决 agent 发现并写 `agent-judgment.md`**：**先写裁决，再修复，再判断是否下一轮**。这是协议强制门——`run_agent.sh` 在你启动新 agent 任务时会扫描 `.agent-loop/*/`，任何已 `done` 的 agent/peer 运行缺少对应 judgment 文件都会直接拒绝。
   - 读完 `agent-output.md` 后，写 `$WORKDIR/.agent-loop/<task-name>/agent-judgment.md`，每条 finding 一行，格式：
     ```
     [<id>] agent:<Severity> → controller:<Severity>  reason: <一句话>
     ```
     `<id>` 可自拟（如 `F1`、`issue-1`），`<Severity>` ∈ `Critical | Major | Minor | Info`，理由用一句话说明为什么同意或降/升级
   - 然后对每条按裁决结果处理：
     - 真 Critical/Major 且明显正确 → 修复，准备下一轮
     - 被降为 Minor/Info → 不修、记录即可
     - 明显错误或脱离上下文 → 拒绝，在 reason 里说明
     - 涉及产品、架构、安全、权衡 → 升级给用户
   - **严重度膨胀对抗**：agent 后期轮次易把"理论可构造"标成 Critical。controller 的 reason 里**必须**直面两个问题：
     - 这条 finding 在真实 LLM 自然合成路径里出现的概率大致是？
     - 修复成本（代码复杂度增量、维护成本）值不值？
   - **盲同意 = 失职**：如果你的 `controller:` 严重度和 `agent:` 完全一致，reason 必须写清楚独立验证了什么，而不是"同意 agent 评估"。
8. **需要第二视角时拉起 peer**：controller 为同一 `<task-name>` 按同一合成契约写 `peer-task.md`——与 `agent-task.md` 的唯一差异是：**指令块的首行必须是** `主 agent 输出路径：<agent-output.md 的绝对路径>`，且该 `agent-output.md` 必须已经存在。`run_agent.sh` / `prompt_protocol.sh` 会校验该行存在、文件存在、canonical 文件本身不是 symlink，确保 peer 始终建立在当前 task 的主 agent 输出之上。
   - 启动命令与步骤 4 相同，仅把末尾的 `agent` 换成 `peer`、prompt 路径换成 `.../<task-name>/peer-task.md`
   - 结果写入 `peer-output.md` / `peer.log`，不会覆盖主 agent 产物
   - peer 完成后，controller 必须读 `peer-output.md` 并写 `peer-judgment.md`，格式与 `agent-judgment.md` 相同但源头字段用 `peer:<Severity>`。peer 的发现同样经 controller 独立重评，才参与继续/终止条件判定。judgment gate 对 agent 和 peer 两类运行独立检查——任何一类缺 judgment 都会拒绝下一轮 agent 启动
9. **有界循环**：每一轮在执行层面独立——agent 不感知上一轮的存在，也不读取上一轮的产物。但 controller 的**调度决策**依赖本轮裁决结果来判断是否继续。
   - **先裁决后终止**：即使某轮表面上已经满足终止条件，controller 也必须先逐条裁决本轮发现，并对“明显正确且局部可执行”的问题先完成修复，再根据修复后的裁决结果判断继续/暂停/终止。禁止在未完成本轮裁决与可直接修复项处理前直接终止。
   - **裁决时重新评估严重度**：agent 的严重度标注仅供参考，controller 必须对每条发现独立判断实际严重度。后期轮次 agent 倾向于严重度膨胀（将 Minor 级问题标为 Major 以维持"仍有重要发现"的表象），controller 不得盲信。
   - **继续条件**：经 controller 重新评估后，本轮存在至少一条被裁决为 Major 及以上的发现（无论是否已修复）→ 修复后**必须**启动下一轮，由新 agent 独立审查当前状态。**禁止以任何理由跳过验证轮**——包括但不限于"修复很简单"、"只是文档补充"、"不存在引入新问题的风险"、"可直接确认正确性"。这些都是 rationalization，不构成跳过验证的合法依据。
   - **暂停条件**：本轮存在无法判断的点 → 升级给用户裁决。用户裁决完成后，controller 根据继续/终止条件决定是否启动下一轮。
   - **终止条件**（满足任一即停止）：
     - 达到最大 3 轮
     - 经 controller 重新评估后，本轮无 Major 及以上级别的发现（即使 agent 标注了 Major，controller 判定实质为 Minor 则视为无 Major）。**注意**：若本轮存在被裁决为真 Major 的发现并已修复，仍属"本轮有 Major"，必须走继续条件启动下一轮验证，不得视为终止

# 工作目录结构

每个任务独占一个子目录，互不干扰：

```text
$WORKDIR/.agent-loop/
  <task-name>/
    agent-task.md    # controller 写入的本轮 agent 任务指令
    peer-task.md     # controller 写入的 peer 任务指令，可选（需包含 agent-output.md 路径）
    agent-output.md  # 主 agent 的结构化发现（controller 读取后裁决）
    peer-output.md   # peer 对主 agent 发现的独立意见，可选（controller 读取后裁决）
    agent-judgment.md # controller 对 agent findings 的独立重评，每条 finding 一行（见下文「controller 裁决与 judgment 文件」）
    peer-judgment.md  # controller 对 peer findings 的独立重评，可选（仅当本轮跑过 peer）
    agent.log        # 主 agent 原始输出，严禁读取（需用户明确授权）
    peer.log         # peer 原始输出，严禁读取（需用户明确授权）
    agent-status.txt # 主 agent 运行状态：空(运行中) | done | error
    peer-status.txt  # peer 运行状态：空(运行中) | done | error
```

## `agent-task.md` / `peer-task.md` 合成契约

生成 prompt 不是机械替换，而是 controller（LLM 智能）对 `templates/agent-prompt.txt` 与 task-module 的一次**智能合成**。目标：把 task-module 里的任务语义精准落入模板的可变槽位，并保证模板的固定部分与协议约束丝毫不动。合成后必须能通过 `scripts/validate_task.sh` 校验。

### 可变槽位（controller 智能填写）

| 槽位 | 对应模板行 | 填写规则 |
|---|---|---|
| 类型 | `- 类型：<...>` | 从模板占位定义的允许集合里选一个值（当前：`review \| discussion \| verification`） |
| 角色 | `- 角色：<...>` | `agent` 或 `peer` |
| 指令块 | `<在此描述具体任务>` | 由 task-module 蒸馏而来的任务指令。允许改写/合并/重排/删冗以保持简洁。**不得**在指令块里重新声明模板固定段（目标词：`硬性规则` / `观点级别定义` / `输出格式` / `严重度诚实原则`）——包括 ATX heading（任意 `#` 深度）、setext heading（`===` 或 `---` 下划线）、任意 markdown emphasis 变体（`*` / `_` 任意组合 + 可选空格）；判定会穿透 markdown 容器前缀：列表 `-` / `*` / `+`、带 `.` 或 `)` 的有序列表、checkbox `[x]` / `[ ]`、blockquote `>`、表格 `\| ... \|`（按单元拆开检测），以及这些的嵌套组合。**也不得**把 severity 四档齐全写进来——判定穿透同样的容器前缀，容忍反引号/方括号/强调包裹与半角/全角冒号。可以只引用其中一两档作为上下文解释，但四档齐全即拒。**代码块豁免**：fenced code block（` ``` ` / `~~~`，closer 需同字符类型且长度 ≥ opener；未闭合则整份拒）与 4 空格缩进的 indented code block 都被视为样例 prose，不触发上述检测。**例外**：4 空格缩进行若去掉缩进后以列表 / blockquote / checkbox / 有序列表 / 表格（`\|` 开头）标记起头，视为"列表/表格的缩进续行"而非 indented code block，仍走上述启发式检测（防止用缩进伪装绕过） |
| 严重度定义块 | `<严重度定义块>` | 四行 `` - `[Level]`：<含义> ``，按 **Critical → Major → Minor → Info** 顺序，每行 body 非空（validator 只校验这一层结构）。含义文本**应**给出可观察的分级维度（如"LLM 自然合成里每百条出现 N 次"、"阻断合法用户 vs 仅误伤低频 case"、"需要刻意构造 vs 常见自然写法"），**避免**只用"显著/明显/轻微/少量"这种主观形容词——主观形容词会让审查 agent 把所有理论可达问题都标 Critical，触发严重度膨胀。此条由 controller 合成时自律遵守，validator 不做语义检查。若 task-module 已有 severity 语义（如 `## 严重度`、`## 严重度标注`），抽出后按这个要求再校准一次；若 task-module 无语义，用下文「默认级别定义」作为 fallback |

### 固定槽位（逐字保留，不得改动）

- `# 硬性规则` 段的 1–8 条全部
- `**严重度诚实原则**` 段
- `# 输出格式` 段（章节标题、例行项、例子占位全部保留）
- 所有章节标题、空行、非占位的注释文本

> 任何对固定槽位的改写——**包括**改标题、改编号、新增或删除一条硬性规则、修改输出格式的占位示例——都会被 validator 逐字拒绝。此外，validator 也会拒绝指令块里**重新声明**这些固定段（详见可变槽位表对"指令块"的约束）。

### peer 专属约束

- 指令块的**首行**必须是：`主 agent 输出路径：<agent-output.md 绝对路径>`（路径必须是同 task 目录下的 `agent-output.md`）
- 该 `agent-output.md` 文件必须已经存在、不是 symlink
- 首行下方可以空一行再写 peer 的补充指令

### 合成纪律

- **蒸馏而非搬运**：task-module 里可能有任务描述、输入输出、审查项、审查原则、原则示例等。把真正对 agent 行动有约束力的内容提炼到指令块；不要把整个文档首尾复制
- **消除冗余**：如果 task-module 里有 `## 严重度 / ## 严重度标注 / ## 级别定义` 这类小节，内容**应**被提升到 `<严重度定义块>` 槽位，而不是同时出现在指令块和观点级别定义两处
- **保留意图**：在不破坏原作者意图的前提下可改写措辞；若某条规则的文本本身已有授权意义（例如引用了外部文档路径），照抄，不要自行重述
- **不要假装更聪明**：task-module 没覆盖到的部分，不要凭空补充规则；不确定就放到"无法判断的点"交给下一轮/用户裁决

### 自检流程

1. 写入 `$WORKDIR/.agent-loop/<task-name>/agent-task.md`（或 `peer-task.md`）
2. `<SKILL_DIR绝对路径>/scripts/validate_task.sh <task-name> <role> [workdir]`（`workdir` 省略时默认 `$PWD`；cwd 不在目标 workdir 时必须显式传）
3. 若 validator 报错：读错误信息 → 修正同一文件 → 重新 validate（不换 task-name；此时仍未产生 agent 运行产物）
4. 通过后才能进入步骤 4（启动 run_agent.sh）

### 观点级别类型的不变性

`Critical / Major / Minor / Info` 四档**作为类型**是协议不变量；合成过程不得增删档位，也不得改名。每一档的**具体含义**可以按任务特化（这就是智能合成的价值）——例如 scenario 审查的 Critical 是"场景越界让后续测试建立在错误边界上"，code review 的 Critical 是"功能错误/安全漏洞"。

默认级别定义如下(这组默认义项适用于大部分通用 code review / 文档审查任务):
- `[Critical]`：功能错误、安全漏洞、数据损坏风险；必须修复并在下一轮验证
- `[Major]`：显著质量问题（性能、可维护性、API 误用）；必须修复并在下一轮验证
- `[Minor]`：风格、文档、可读性问题；可选修复
- `[Info]`：纯观察或背景说明，无需动作

task-module 有自己的 severity 语义时，优先使用 task-module 的（比如 scenario-review.md、plan-review.md 等的 `## 严重度` 小节）；task-module 无 severity 语义时，结合默认级别定义生成合理的级别定义（实在无法确定时，建议直接使用默认级别定义）。

## controller 裁决与 judgment 文件

控制严重度膨胀的核心机制：每次 agent 或 peer 完成后，controller **必须**写同目录下对应的 judgment 文件，对每条 finding 独立再评估，再决定修/不修/下一轮。

- agent 完成 → `agent-judgment.md`（源头字段为 `agent:<Severity>`）
- peer 完成 → `peer-judgment.md`（源头字段为 `peer:<Severity>`）

两份文件互不覆盖；只跑了 agent 时 `peer-judgment.md` 不存在也无所谓，跑了哪个就写哪个对应的 judgment。

### 文件位置与格式

`$WORKDIR/.agent-loop/<task-name>/{agent,peer}-judgment.md`，纯文本，每条 finding 一行：

```
[<id>] <agent|peer>:<Severity> → controller:<Severity>  reason: <一句话独立判断依据>
```

- `<id>`：自拟（`F1`、`bypass-ghm` 之类），与对应 output 文件中的 finding 对应即可
- 源头字段：agent-judgment.md 的每行用 `agent:<S>`，peer-judgment.md 的每行用 `peer:<S>`
- `<Severity>`：`Critical | Major | Minor | Info` 其中之一
- `reason`：不允许只写"同意 agent/peer"；必须说明独立验证了什么、或为何降/升级、或为何此路径不算"自然合成"

一个示例（agent-judgment.md）：

```
[F1] agent:Critical → controller:Major  reason: CRLF 行尾在 Windows 编辑器常见，阻断合法用户；改一行 mapfile 后置处理即可
[F2] agent:Critical → controller:Minor  reason: 需要 30+ 字符中文注释才能触发，合成纪律要求蒸馏、不会自然写出这么长
[F3] agent:Critical → controller:Minor  reason: emoji 前缀伪装重述，合成契约已禁止指令块装饰化；修复成本高于收益
```

### run_agent.sh 的强制门

当你调用 `run_agent.sh` 启动**新 agent 任务**时，脚本会扫描 `$WORKDIR/.agent-loop/*/`，对每个已 `done` 但缺少对应 judgment 文件的历史运行 → **拒绝启动**，列出缺失路径。判定规则：
- `agent-status.txt == "done"` 且有 `agent-output.md` → 必须有 `agent-judgment.md`
- `peer-status.txt == "done"` 且有 `peer-output.md` → 必须有 `peer-judgment.md`

agent 和 peer 两类独立检查，任一缺失都会拒绝下一轮 agent 启动。这是物理层拦截 autopilot。

使用 `--skip-judgment-check` 可绕过（仅用于历史目录清理、自动化测试等）。日常流程不应使用。

### 与继续/终止条件的关系

步骤 9 的"继续条件"**在 controller 重评后生效**：本轮所有 judgment 文件（agent 的，以及 peer 跑过时 peer 的）里没有 `controller:` 标为 Major 及以上的 finding → 无论 agent/peer 标了多少 Critical，本轮都视为无真 Major → 可以终止。

**用户 override 3 轮上限时的额外纪律**：用户说"继续跑到无 Major+"时，controller 仍然按 judgment 文件里**自己重评**的严重度判断，而不是按 agent/peer 标注。若连续 2 轮新发现的真 Major 全部属于"需要更复杂输入才能触发"（路径越来越曲折、复杂度增量远大于实际收益），视为膨胀信号，主动终止并报告给用户。

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
- 每一轮使用唯一 task-name，禁止多任务或多轮次共用同一工作目录
- 必须限制循环轮数，禁止无界自反馈；升级条件必须明确：架构取舍、权限边界、安全风险
- controller 只通过文件读取 **agent 子进程**的结构化输出，不内联读取 agent/peer 的 stdout/stderr；`run_agent.sh` 壳脚本自身的 stderr 可以读，用于排查 prelaunch 阶段被拒原因（参数、协议、复用拦截）
- controller 裁决时必须独立判断严重度，不得直接采信 agent 标注——已知退化模式：后期轮次 agent 将 Minor 膨胀为 Major、将"修复未传播"包装为新发现
- controller 必须先完成本轮裁决与可直接修复项处理，再判断是否终止；不得因"表面满足终止条件"而提前停在未裁决状态
- controller 每轮合成 `agent-task.md` / `peer-task.md` 后必须先通过 `scripts/validate_task.sh` 自检；自检通过后才能调用 `run_agent.sh`。不得绕过 validator 直接启动 runner
- controller 每次 agent/peer 完成后必须写对应的 judgment 文件再进入修复/下一轮（格式、gate 机制、反盲同意要求详见步骤 7 / 步骤 8 与「controller 裁决与 judgment 文件」章节）
- task-module 的「观点级别定义」应包含可观察的分级维度（如"LLM 自然合成出现频率"、"是否阻断下游"），避免只用"显著/明显/轻微/少量"这种主观形容词——主观定义会直接诱发审查 agent 的严重度膨胀。此条是 controller 合成时的自律约束，validator 不做语义检查
- peer 任务必须建立在当前 task 的 `agent-output.md` 之上：指令块首行须写成 `主 agent 输出路径：<绝对路径>`，该文件必须存在且不是 symlink

# 验证方式

最小验证：

1. **runner × role 矩阵**：对当前环境**已安装的每个** runner（`{codex, claude, crush, opencode}` 的非空子集，至少一个）使用各自独立的 task-name；在每个 task-name 内先跑 `agent` 再跑 `peer`（peer 必须指向同 task 的 `agent-output.md`），确认产生 `agent-output.md` / `agent.log` / `agent-status.txt`，peer 后续产出 `peer-output.md` / `peer.log` 且不覆盖主 agent 产物。未安装的 runner 跳过即可，不是验证失败
2. **并行隔离**：多个 task-name 并行不冲突
3. **git exclude**：首次运行后 `.agent-loop/` 已被写入 `<repo>/.git/info/exclude`
4. **validator — agent**：按合成契约手写一份 `agent-task.md`，`scripts/validate_task.sh <task-name> agent` 通过；再分别制造缺陷（改坏固定章节文本、类型越界、severity 缺级 / 乱序 / body 为空、canonical prompt 换 symlink），确认 validator 给出明确错误并拒绝
5. **validator — peer**：先让 agent 跑一轮产出 `agent-output.md`，再手动合成 `peer-task.md`（首行须为 `主 agent 输出路径：<绝对路径>`），`validate_task.sh <task-name> peer` 通过；移除首行 / 换 symlink / 删除 `agent-output.md`，分别确认被拒绝
6. **judgment gate**：让 agent 跑完一轮产出 `agent-output.md` + `agent-status.txt == done`，**不写** `agent-judgment.md`，尝试用新 task-name 启动 agent 角色应被 `run_agent.sh` 拒绝（错误信息列出缺失的 `agent-judgment.md` 路径）；写入后重试应通过。再在某一 task 下跑 peer 产出 `peer-output.md` + `peer-status.txt == done`，同样验证缺 `peer-judgment.md` 会拒绝下一轮 agent 启动，补上后通过。`--skip-judgment-check` 能绕过（仅用于历史清理/测试）

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
- 不负责自动解决 controller 与 peer 之间的所有冲突

# 引用资料

- `$SKILL_DIR/scripts/run_agent.sh` — runner 包装脚本，controller 通过它启动 agent（推荐用 `--detach=auto` 让脚本自行决定是否脱离）。启动前会调用 validator 二次校验 prompt 文件
- `$SKILL_DIR/scripts/validate_task.sh` — controller 合成 `agent-task.md` / `peer-task.md` 后的自检入口；传入 `<task-name> <role> [workdir]`，失败时给出精确错误信息，controller 据此修正再次校验
- `$SKILL_DIR/scripts/prompt_protocol.sh` — validator 与 runner 共享的模板协议解析与校验逻辑；负责模板加载、固定槽位逐字比对、severity 四行校验、peer 的 canonical `agent-output.md` 校验
- `$SKILL_DIR/templates/agent-prompt.txt` — controller 合成 `agent-task.md` / `peer-task.md` 时的模板源文件，包含所有固定槽位与占位
- 本机 CLI 自检：`codex exec --help`
- 本机 CLI 自检：`claude --help`
- 本机 CLI 自检：`crush run --help`
- 本机 CLI 自检：`opencode run --help`
