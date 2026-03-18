---
name: multi-agent-loop
description: 通过文件协议协调多个 coding agent（Claude、Codex）在有界循环中完成 review、discussion、implementation、verification 等任务。
metadata:
  version: 1.2.0
---

# 适用场景

- 需要让一个 coding agent 调用另一个 coding agent 做 review、discuss、verify、implement
- 需要多个独立视角，但不想把长日志直接灌进当前会话上下文
- 需要有界循环，最多跑固定轮数，再由 controller 或用户裁决
- 支持以下拓扑：
  - `Claude → Codex`
  - `Claude → Claude`（通过 `claude -p` CLI 子进程，保持上下文隔离）
  - `Codex → Codex`
  - `Codex → Claude`

# 核心概念

- **controller**：发起循环、读取 worker 结论、逐条裁决的 agent（通常是当前会话里的 Claude Code）。不执行任务本身，只指挥和裁决。
- **worker（主）**：被 controller 拉起、执行具体任务、把结构化发现写入 `worker-output.md` 的 agent。只报告观察到的事实和无法判断的点，不做裁决。
- **peer（副，可选）**：读取主 worker 的 `worker-output.md`，对其中的发现提出独立意见（支持、质疑或补充），写入 `peer-output.md`。peer 同样只输出观点，不做裁决。
- **关键澄清**：这里的"agent 调用 agent"是通过 CLI 子进程 + 文件协议完成的，不是模型内部原生互调。`claude -p` 与 `codex exec` 均作为独立子进程运行，输出不会污染 controller 的上下文。

# 必须材料

- 当前环境至少安装一个可无头执行的 agent CLI：`codex` 或 `claude`
- `scripts/run_agent.sh`
- 每个任务有唯一的任务名（task-name），用于隔离工作目录

# 执行步骤

1. **确认拓扑**：明确谁是 controller，谁是 worker，是否需要 peer。
2. **选定任务名**：每个任务使用唯一的 `<task-name>`，工作目录为 `$WORKDIR/.agent-loop/<task-name>/`，多任务并行不冲突。
3. **写入本轮任务**：controller 将任务描述写入 `$WORKDIR/.agent-loop/<task-name>/task.md`，参考 `templates/agent-prompt.txt`，要求 worker 只输出结构化发现，不输出推理过程或完整日志。
4. **静默启动 worker**：
   - `codex` 主 worker：`./scripts/run_agent.sh codex <task-name> <task.md路径> agent <workdir>`
   - `claude` 主 worker：`./scripts/run_agent.sh claude <task-name> <task.md路径> agent <workdir>`
   - worker 以后台进程运行，controller 不阻塞等待。
5. **轮询等待 worker 完成**：worker 执行耗时因任务复杂度差异很大（数秒到数分钟均属正常），controller 需要耐心等待，通过定时轮询 `*-status.txt` 判断是否完成：
   - 轮询间隔：每 **30 秒** 检查一次 `worker-status.txt`（或 `peer-status.txt`）
   - 超时上限：**10 分钟**；超时后视为 error，记录日志并升级给用户
   - 判断逻辑：文件内容为 `done` → 成功完成；`error` → 失败；空或不存在 → 仍在运行
   - 轮询期间 controller 不应做其他裁决动作，避免读到不完整的输出
6. **只读取结构化文件**：
   - 允许读取：`worker-output.md`、`peer-output.md`（如有 peer）
   - 不允许默认读取：`worker.log`、`peer.log`
7. **controller 逐条裁决 worker 发现**：worker 可能返回多条独立发现，controller 对每一条独立判断：
   - 明显正确且局部可执行 → 直接应用
   - 明显错误或脱离上下文 → 拒绝，记录原因
   - 涉及产品、架构、安全、权衡判断 → 暂停，升级给用户
8. **需要第二视角时拉起 peer**：controller 用相同脚本、`role=peer` 启动 peer，结果自动写入 `peer-output.md` / `peer.log`，不会覆盖主 worker 产物。peer 读取主 worker 的 `worker-output.md`，输出自己对这份发现的独立意见（支持、质疑或补充）。controller 读取两份发现后再裁决。
   - `codex` peer：`./scripts/run_agent.sh codex <task-name> <peer-task.md路径> peer <workdir>`
   - `claude` peer：`./scripts/run_agent.sh claude <task-name> <peer-task.md路径> peer <workdir>`
9. **有界循环**：每一轮独立运行，与上一轮无因果依赖（上一轮的变更可能被顺带审查，但不是触发下一轮的条件）。满足以下任一条件即停止：
   - 达到最大论述 3 轮时
   - 本轮 worker 没有 Major 及以上级别的观点时
   - 本轮存在无法判断的点时(停止之后, 还要升级给用户裁决)

# 工作目录结构

每个任务独占一个子目录，互不干扰：

```text
$WORKDIR/.agent-loop/
  <task-name>/
    task.md         # controller 写入的本轮任务指令
    worker-output.md # 主 worker 的结构化发现（controller 读取后裁决）
    peer-output.md  # peer 对主 worker 发现的独立意见，可选（controller 读取后裁决）
    worker.log         # 主 worker 原始输出，默认禁止读取
    peer.log          # peer 原始输出，默认禁止读取
    worker-status.txt  # 主 worker 运行状态：done | error
    peer-status.txt   # peer 运行状态：done | error
```

## `task.md` 最小模板

```md
# 任务

- 类型：review | discussion | implementation | verification | refactoring
- 角色：agent → 输出文件 $WORKDIR/.agent-loop/<task-name>/worker-output.md
  peer → 输出文件 $WORKDIR/.agent-loop/<task-name>/peer-output.md

# 指令

<具体任务描述>

# 输出规范

- 将结构化发现作为最终回复内容输出到 stdout，不要主动写文件
- runner 统一负责将 stdout 落盘到输出文件（codex 用 `-o`，claude 用重定向）
- 不输出推理过程、完整日志或大段 diff
- 只报告观察到的事实；无法独立判断的点单独列出，不要强行给出结论
```

## `worker-output.md` 推荐格式

```md
## 发现 / 变更
- [Critical] [文件:行号] 具体描述
- [Major] [文件:行号] 具体描述
- [Minor] [文件:行号] 具体描述

## 依据
- 对应上方每条发现的支撑证据，保持一一对应

## 无法判断的点
- 需要产品知识、架构背景或更多信息；若无则写"无"
```

级别说明：
- `[Critical]`：功能错误、安全漏洞、数据损坏风险；有 Critical 则 controller 继续循环
- `[Major]`：显著质量问题；强烈建议修复，不强制继续循环
- `[Minor]`：风格、文档、可读性；可选修复
- `[Info]`：纯观察，无需动作

# 质量门槛

- 必须区分 `controller` 与 `worker`，controller 不执行任务，只裁决
- 必须使用唯一 task-name，禁止多任务共用同一工作目录
- controller 只通过文件读取 worker 输出，不内联读取任何 agent 的 stdout/stderr；runner 负责把 worker 输出落盘（codex 用 `-o`，claude 用 stdout 重定向），两种机制均符合此约束
- 必须限制循环轮数，禁止无界自反馈
- 升级条件必须明确：架构取舍、权限边界、安全风险
- 不得宣称"agent 原生互调"；准确表述为"controller 通过 CLI 子进程启动 worker"
- 结构化输出文件必须与原始日志文件分离
- `worker-status.txt` / `peer-status.txt` 有两个用途：①轮询判断 worker 是否完成（步骤 5）；②判断本次 `run_agent.sh` 调用是否成功。**不用于决定是否发起下一轮**——是否继续循环由 controller 根据裁决结果判断
- `run_agent.sh` 首次运行时自动将 `.agent-loop/` 加入 `.git/info/exclude`，避免协议文件污染 worker 的仓库视图

# 验证方式

最小验证：

1. 执行 `./skills/multi-agent-loop/scripts/run_agent.sh codex test-task .agent-loop/test-task/task.md agent <repo>`，确认产生 `worker-output.md`、`worker.log`、`worker-status.txt`
2. 执行 `./skills/multi-agent-loop/scripts/run_agent.sh codex test-task .agent-loop/test-task/peer-task.md peer <repo>`，确认产生 `peer-output.md`、`peer.log`，且 `worker-output.md` 未被覆盖
3. 执行 `./skills/multi-agent-loop/scripts/run_agent.sh claude test-task .agent-loop/test-task/task.md agent <repo>`，确认行为一致
4. 确认多个 task-name 并行不冲突

# 不覆盖范围

- 不负责绕过宿主平台的权限模型
- 不保证所有 agent CLI 支持相同的工具权限和工作目录语义
- 不负责跨机器调度、队列或真正的分布式编排
- 不负责自动解决 controller 与 peer 之间的所有冲突

# 引用资料

- `scripts/run_agent.sh` — runner 包装脚本，controller 通过它静默启动 worker
- `templates/agent-prompt.txt` — controller 每轮写入 `task.md` 时参考的模板，填入具体任务描述后发给 worker
- 本机 CLI 自检：`codex exec --help`
- 本机 CLI 自检：`claude --help`
