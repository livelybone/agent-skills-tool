---
name: multi-agent-loop
description: 通过文件协议协调多个 coding agent（Claude、Codex、Crush、OpenCode）在有界循环中完成 review、discussion、implementation、verification、refactoring 等任务。
metadata:
  version: 1.2.0
---

# 适用场景

- 需要让一个 coding agent 调用另一个 coding agent 做 review、discussion、implementation、verification、refactoring
- 需要多个独立视角，但不想把长日志直接灌进当前会话上下文
- 需要有界循环，最多跑固定轮数，再由 controller 或用户裁决
- 支持以下 runner：`claude`、`codex`、`crush`、`opencode`，可自由组合拓扑（如 `Claude → Crush`、`Claude → OpenCode` 等）

# 核心概念

- **controller**：发起循环、读取 agent 结论、逐条裁决的角色（通常是当前会话里的 Claude Code）。不执行任务本身，只指挥和裁决。
- **agent（主）**：被 controller 拉起、执行具体任务、把结构化发现写入 `agent-output.md` 的子进程。覆盖所有任务类型——review、discussion、implementation、verification、refactoring 均由 agent 角色承担。只报告观察到的事实和无法判断的点，不做裁决。
- **peer（副，可选）**：在 agent 已产出 `agent-output.md` 的前提下，读取该产出并提出独立意见（支持、质疑或补充），写入 `peer-output.md`。peer 是对 agent 结论的第二视角挑战，不是独立执行任务的角色。peer 同样只输出观点，不做裁决。
- **角色选择原则**：需要执行一项任务（含审查）→ 用 agent；需要挑战 agent 已有结论 → 用 peer。审查已有产物（如 review Spec、review Test）属于"执行审查任务"，应使用 agent 角色而非 peer。
- **关键澄清**：这里的"agent 调用 agent"是通过 CLI 子进程 + 文件协议完成的，不是模型内部原生互调。`claude -p` 与 `codex exec` 均作为独立子进程运行，输出不会污染 controller 的上下文。

# 必须材料

- 当前环境至少安装一个可无头执行的 agent CLI：`codex`、`claude`、`crush` 或 `opencode`
- `$SKILL_DIR/scripts/run_agent.sh`（`$SKILL_DIR` 指本 skill 的安装目录，即包含此 `SKILL.md` 的目录）
- 每一轮执行都必须有唯一的任务名（task-name），用于隔离工作目录；禁止把不同轮次复用到同一个 task-name

# 执行步骤

1. **确认拓扑**：明确谁是 controller，谁是 agent，是否需要 peer。
2. **选定任务名**：每一轮执行都使用唯一的 `<task-name>`，工作目录为 `$WORKDIR/.agent-loop/<task-name>/`，多任务并行不冲突。
   - 推荐命名：`<step>-<module>-r1`、`<step>-<module>-r2`、`<step>-<module>-r3`
   - 禁止复用如 `review-spec-payment` 这样的固定 task-name 跑多轮；当前脚本会拒绝复用同角色产物，从而避免后续轮次覆盖前一轮的 `agent-output.md` / `peer-output.md`
3. **写入本轮任务**：controller 将任务描述写入 `$WORKDIR/.agent-loop/<task-name>/agent-task.md`，参考 `templates/agent-prompt.txt`，要求 agent 只输出结构化发现，不输出推理过程或完整日志。
4. **启动 agent**：`run_agent.sh` 默认是同步阻塞的。
   - **推荐入口**：优先使用 `--detach=auto`。有 `tmux` 时会自动脱离到独立 tmux session；没有 `tmux` 时回退到普通同步模式。
   - **controller 责任**：
     - 使用 `--detach=tmux` 时，`run_agent.sh` 会在返回前预创建空的 `*-status.txt`，controller 可立即开始轮询，**不要再额外追加 `&`**
     - 使用 `--detach=auto` 时，若当前机器装有 `tmux`，行为与 `--detach=tmux` 相同；若没有 `tmux`，则退化为同步阻塞模式
     - 使用 `--detach=none` 或不传 detach 参数时，controller 如需非阻塞，仍需自己做后台化（如 `run_in_background`、`&`）
   - **当前环境优先做法**：如果 controller 需要可靠的“立即返回后轮询”，优先确保宿主机有 `tmux` 并使用 `--detach=auto` 或 `--detach=tmux`
   - **命令格式约束**：构造 Bash 命令时，必须先将 `$SKILL_DIR` 解析为绝对路径字符串，然后在命令中直接使用该绝对路径字面量。**禁止**在 Bash 命令中使用 `$SKILL_DIR` 变量引用（如 `$SKILL_DIR/scripts/...`）或内联赋值（如 `SKILL_DIR="..." $SKILL_DIR/scripts/...`）。这确保命令格式一致，便于权限规则匹配。
   - `codex` 主 agent：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto codex <task-name> <agent-task.md路径> agent <workdir>`
      - ⚠️ macOS + Claude Code 环境下，必须以 `dangerouslyDisableSandbox: true` 调用（详见「已知平台问题」）。Codex 自身沙箱仍生效，安全性不受影响。
   - `claude` 主 agent：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto claude <task-name> <agent-task.md路径> agent <workdir>`
     - 无平台限制，可在任意环境直接运行。
   - `crush` 主 agent：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto crush <task-name> <agent-task.md路径> agent <workdir>`
     - 通过 `crush run` 非交互模式执行，需预先配置 provider。
   - `opencode` 主 agent：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto opencode <task-name> <agent-task.md路径> agent <workdir>`
     - 通过 `opencode run` 非交互模式执行，支持内置免费模型或自配 provider。
   - 自动脱离模式：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto <runner> <task-name> <agent-task.md路径> agent <workdir>`
     - 有 `tmux` 时自动使用独立 tmux session
     - 没有 `tmux` 时自动回退到普通同步模式
   - `tmux` 脱离模式：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=tmux <runner> <task-name> <agent-task.md路径> agent <workdir>`
     - 适用于 controller 的宿主环境会在命令返回后清理后台子进程的情况
     - runner 会在独立的 tmux session 中执行，stdout 返回 `detached:<session-name>`
     - `*-status.txt` 会在命令返回前以空文件形式创建，因此 controller 可以立即轮询；若文件不存在，仍应视为参数校验失败
   - 显式禁用脱离：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=none <runner> <task-name> <agent-task.md路径> agent <workdir>`
     - 强制使用当前进程模型
   - 兼容别名：`--detach-tmux`
     - 等价于 `--detach=tmux`
5. **轮询等待 agent 完成**：agent 执行耗时因任务复杂度差异很大（数秒到数分钟均属正常），controller 需要耐心等待，通过定时轮询 `*-status.txt` 判断是否完成：
   - 轮询间隔：每 **30 秒** 检查一次 `agent-status.txt`（或 `peer-status.txt`）
   - 超时上限：**10 分钟**；超时后视为 error，记录日志并升级给用户
   - 判断逻辑：文件内容为 `done` → 成功完成；`error` → 失败；空 → 仍在运行。正常流程中 status 文件在参数校验通过后立即创建（空文件），因此"文件不存在"不是合法的运行中状态——它意味着参数校验失败（controller 编程错误），controller 应检查调用参数而非继续轮询
   - 轮询期间 controller 不应做其他裁决动作，避免读到不完整的输出
   - **禁止使用 `agent.log` / `peer.log` 推断运行状态**：不得通过 `wc -c`、`ls -la`、`tail` 等任何方式读取或探测 log 文件来判断 agent 是否仍在运行。唯一的状态判断来源是 `*-status.txt`。status 为空说明 agent 仍在运行，继续等待即可
6. **只读取结构化文件**：
   - 允许读取：`agent-output.md`、`peer-output.md`（如有 peer）
   - **严禁以任何方式访问 `agent.log`、`peer.log`**——包括但不限于 `cat`、`head`、`tail`、`wc`、`ls -la`、`stat` 等读取内容或元数据的操作。除非用户明确授权（如调试失败时用户主动要求查看），读取前必须向用户确认
7. **controller 逐条裁决 agent 发现**：agent 可能返回多条独立发现，controller 对每一条独立判断：
   - 明显正确且局部可执行 → 直接应用
   - 明显错误或脱离上下文 → 拒绝，记录原因
   - 涉及产品、架构、安全、权衡判断 → 暂停，升级给用户
8. **需要第二视角时拉起 peer**：controller 编写单独的 peer 任务文件（如 `peer-task.md`），在指令中明确包含 `agent-output.md` 的路径，要求 peer 读取后给出独立意见。controller 用相同脚本、`role=peer` 启动 peer，结果自动写入 `peer-output.md` / `peer.log`，不会覆盖主 agent 产物。controller 读取两份发现后再裁决。
   - `codex` peer：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto codex <task-name> <peer-task.md路径> peer <workdir>`
   - `claude` peer：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto claude <task-name> <peer-task.md路径> peer <workdir>`
   - `crush` peer：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto crush <task-name> <peer-task.md路径> peer <workdir>`
   - `opencode` peer：`<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto opencode <task-name> <peer-task.md路径> peer <workdir>`
9. **有界循环**：每一轮在执行层面独立——agent 不感知上一轮的存在，也不读取上一轮的产物。但 controller 的**调度决策**依赖本轮裁决结果来判断是否继续。
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
    agent.log        # 主 agent 原始输出，严禁读取（需用户明确授权）
    peer.log         # peer 原始输出，严禁读取（需用户明确授权）
    agent-status.txt # 主 agent 运行状态：空(运行中) | done | error
    peer-status.txt  # peer 运行状态：空(运行中) | done | error
```

## `agent-task.md` / `peer-task.md` 编写方式

controller 每轮写入任务文件时，以 `templates/agent-prompt.txt` 为基础模板，只需填入「类型」「角色」和「指令」三个字段。模板已包含硬性规则、级别定义和输出格式，不要另行简化或裁剪。

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

级别说明：

- `[Critical]`：功能错误、安全漏洞、数据损坏风险；必须修复并在下一轮验证
- `[Major]`：显著质量问题（性能、可维护性、API 误用）；必须修复并在下一轮验证
- `[Minor]`：风格、文档、可读性问题；可选修复
- `[Info]`：纯观察或背景说明，无需动作

# 质量门槛

- 必须区分 `controller` 与 `agent`，controller 不执行任务，只裁决
- 必须使用唯一 task-name，禁止多任务或多轮次共用同一工作目录
- controller 只通过文件读取 agent 输出，不内联读取任何子进程的 stdout/stderr；runner 负责把 agent 输出落盘（codex 用 `-o`，claude/crush/opencode 用 stdout 重定向），所有机制均符合此约束
- 必须限制循环轮数，禁止无界自反馈
- 升级条件必须明确：架构取舍、权限边界、安全风险
- 不得宣称"agent 原生互调"；准确表述为"controller 通过 CLI 子进程启动 agent"
- controller 裁决时必须独立判断严重度，不得直接采信 agent 标注。已知退化模式：后期轮次 agent 将 Minor 膨胀为 Major、将"修复未传播"包装为新发现
- 结构化输出文件必须与原始日志文件分离
- `run_agent.sh` 会拒绝复用已存在同角色产物的 task-name；controller 看到该错误时，应新建下一轮目录而不是重试覆盖
- `run_agent.sh` 现在会在异常退出（包括被 `TERM/HUP/INT` 打断）时将 `*-status.txt` 写为 `error`，避免遗留空状态文件误判为"仍在运行"
- `--detach=tmux` 会在外层命令返回前预创建空的 `*-status.txt`；因此在该模式下，controller 可以立即开始轮询，而不必容忍“文件暂时不存在”的过渡窗口
- `agent-status.txt` / `peer-status.txt` 有两个用途：①轮询判断 agent 是否完成（步骤 5）；②判断本次 `run_agent.sh` 调用是否成功。**不用于决定是否发起下一轮**——是否继续循环由 controller 根据裁决结果判断。注意：若 `run_agent.sh` 在参数校验阶段（参数不足、workdir 不存在、task-name 非法、role 非法、prompt 文件不存在）就退出，status 文件不会被创建——controller 应确保调用参数正确，这些是 controller 编程错误而非运行时失败
- `run_agent.sh` 首次运行时自动将 `.agent-loop/` 加入 `.git/info/exclude`，避免协议文件污染 agent 的仓库视图

# 验证方式

最小验证：

1. 执行 `<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto codex test-codex .agent-loop/test-codex/agent-task.md agent <repo>`，确认产生 `agent-output.md`、`agent.log`、`agent-status.txt`
2. 执行 `<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto codex test-codex .agent-loop/test-codex/peer-task.md peer <repo>`，确认产生 `peer-output.md`、`peer.log`，且 `agent-output.md` 未被覆盖
3. 执行 `<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto claude test-claude .agent-loop/test-claude/agent-task.md agent <repo>`，确认行为一致
4. 执行 `<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto crush test-crush .agent-loop/test-crush/agent-task.md agent <repo>`，确认行为一致
5. 执行 `<SKILL_DIR绝对路径>/scripts/run_agent.sh --detach=auto opencode test-opencode .agent-loop/test-opencode/agent-task.md agent <repo>`，确认行为一致
6. 对 claude/crush/opencode 分别以各自的 task-name 执行 peer 角色（如 `test-claude` + `role=peer`），确认 `peer-output.md` / `peer.log` 正确生成且不覆盖对应 agent 产物
7. 确认多个 task-name 并行不冲突
8. 确认首次运行后 `.agent-loop/` 已被写入 `<repo>/.git/info/exclude`

# 已知平台问题

| 平台                        | Runner     | 问题                                                                                                                   | 应对                                                                                                                        |
| --------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| macOS + Claude Code sandbox | `codex`    | Claude Code sandbox 阻止访问 macOS `SCDynamicStore` 系统守护进程，导致 Codex CLI 的 `system-configuration` crate panic | controller 启动 `codex` agent 时必须禁用 sandbox（`dangerouslyDisableSandbox: true`），或改用 `claude` runner（不受此影响） |
| macOS + Claude Code sandbox | `crush`    | **未验证**：Crush 基于 Go，可能触发类似系统调用限制                                                                     | 优先尝试 sandbox 内运行；若失败则 `dangerouslyDisableSandbox: true`                                                         |
| macOS + Claude Code sandbox | `opencode` | **未验证**：OpenCode 基于 Node.js，可能触发类似限制                                                                     | 同上                                                                                                                        |
| 任意                        | `crush`    | `crush run` + tool calling（文件写入等）存在[已知 bug](https://github.com/charmbracelet/crush/issues/1322)              | 仅用于 review/discussion 等只读任务；implementation 任务优先用 `claude` 或 `codex`                                           |

# 不覆盖范围

- 不负责绕过宿主平台的权限模型
- 不保证所有 agent CLI 支持相同的工具权限和工作目录语义
- 不负责跨机器调度、队列或真正的分布式编排
- 不负责自动解决 controller 与 peer 之间的所有冲突

# 引用资料

- `$SKILL_DIR/scripts/run_agent.sh` — runner 包装脚本，controller 通过它启动 agent（推荐用 `--detach=auto` 让脚本自行决定是否脱离）
- `$SKILL_DIR/templates/agent-prompt.txt` — controller 每轮写入 `agent-task.md` / `peer-task.md` 时参考的模板，填入具体任务描述后发给 agent 或 peer
- 本机 CLI 自检：`codex exec --help`
- 本机 CLI 自检：`claude --help`
- 本机 CLI 自检：`crush run --help`
- 本机 CLI 自检：`opencode run --help`
