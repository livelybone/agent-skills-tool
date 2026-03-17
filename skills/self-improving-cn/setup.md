# 初始化 —— 自我进化代理

## 首次设置

### 1. 创建记忆目录结构

```bash
mkdir -p ~/self-improving/{projects,domains,archive}
```

### 2. 初始化核心文件

使用 `memory-template.md` 创建 `~/self-improving/memory.md`：

```markdown
将 `memory-template.md` 的结构复制到 `~/self-improving/memory.md`。
```

`memory.md` 基础模板：
```markdown
# Memory (HOT Tier)

## Preferences

## Patterns

## Rules
```

创建 `~/self-improving/corrections.md`：
```markdown
# Corrections Log

| Date | What I Got Wrong | Correct Answer | Status |
|------|-----------------|----------------|--------|
```

创建 `~/self-improving/index.md`：
```markdown
# Memory Index

| File | Lines | Last Updated |
|------|-------|--------------|
| memory.md | 0 | — |
| corrections.md | 0 | — |
```

### 3. 配置运行模式（强制）

这是必做步骤。必须先将一个运行模式块写入当前生效的全局宿主 steering 文件，本技能才能视为已安装并已启用。

将以下内容写入宿主运行时实际读取的全局 steering 文件（支持时使用 `AGENTS.md`，否则写入平台原生 steering 文件）。不要把一个未接入宿主的项目本地 steering 文件视为完成：

```markdown
## Self-Improving Mode

Current mode: Active

Available modes (coding-agent):
- Passive:
  - 任务开始只加载 HOT 记忆
  - 仅记录明确纠错
  - 不主动发起规则晋升
- Active:
  - 在 Passive 基础上追踪重复模式
  - 同类信号出现 3 次后询问是否固化
  - 任务结束执行反思写回
- Strict:
  - 在 Active 基础上，写入 memory.md/projects/domains 前一律确认
  - 只要记忆影响输出，就必须附来源引用
```

所有模式都必须具备的最小钩子：
- 任务开始：读取 `~/self-improving/memory.md` 与 `index.md`
- 明确纠错：写入 `~/self-improving/corrections.md`
- 最终回复前：执行一次 write-back 检查（`updated` 或 `no-op`）

不得跳过本节。若宿主实际使用的全局 steering 文件中没有写入运行模式配置，则 setup 仍未完成。

### 4. Steering 文件映射（所有 Coding Agent，强制）

这是必做步骤。只要没有把契约映射并写入正确的全局宿主 steering 文件，就不能把 `self-improving` 视为已安装或已启用。

必须按当前平台选择且完成唯一主入口文件映射：
- Claude Code：全局 `CLAUDE.md`（仅当工作区 steering 文件就是宿主真实入口时才使用工作区文件）
- Codex / OpenCode：运行时实际读取的全局 `AGENTS.md`（优先）
- Gemini：全局 `GEMINI.md`（或系统指令文件）

不要在创建完 `~/self-improving/` 目录和文件后就停止；未完成该全局 steering 映射前，整个 setup 都算未完成。宿主不会读取的项目本地文件不算完成。

### 5. 无破坏增强主 Steering 文件的 Memory 段（强制）

这是必做步骤。在不替换整段、不过度删改原有内容的前提下，补充主全局 steering 文件（支持时优先 `AGENTS.md`，否则使用宿主实际加载的平台原生 steering 文件）中的 `## Memory`。允许非破坏编辑，但不允许省略下述补充内容。

如果你的 `## Memory` 与模板不同，请在语义等价位置插入下列内容。缺少这些补充时，setup 仍应视为未完成。

在连续性条目（如 Daily notes / Long-term）附近加入：

```markdown
- **Self-improving:** `~/self-improving/`（通过 `self-improving` skill）——执行质量记忆（偏好、工作流、风格模式、哪些做法提升或降低了结果）
```

在 “Capture what matters...” 之后加入：

```markdown
Use `memory/YYYY-MM-DD.md` and `MEMORY.md` for factual continuity (events, context, decisions).
Use `~/self-improving/` for compounding execution quality across tasks.
For compounding quality, capture clear execution-improvement signals in `~/self-improving/`: preferences, workflow/style choices, what improved or degraded results, and high-signal inferences for next time.
If in doubt, store factual history in `memory/YYYY-MM-DD.md` / `MEMORY.md`, and store reusable performance lessons in `~/self-improving/` (tentative until human validation).
```

在 “Write It Down” 子段之前加入：

```markdown
When writing or organizing in `~/self-improving/`, read `self-improving` `SKILL.md` first.
If inferring a new rule, keep it tentative until human validation.
```

在 “Write It Down” 的条目中，必须按“非破坏”方式细化（保留原意）：
- 将执行质量相关内容路由到 `~/self-improving/`
- 若原文完全一致，可只替换目标行；若不一致，做等价改写，不删无关规则

目标表述：

```markdown
- When someone says "remember this" → if it's factual context/event, update `memory/YYYY-MM-DD.md`; if it's a correction, preference, workflow/style choice, or performance lesson, log it in `~/self-improving/` via the `self-improving` skill
- When you learn a lesson → store it in `~/self-improving/` by default; update global steering/guardrail docs only when the rule is truly cross-domain
- When you make a mistake → document it in `~/self-improving/corrections.md` so future behavior improves; escalate to global steering/guardrails only for broad, always-on rules
```

## Coding-Agent 接入（Claude Code / Codex / Gemini / OpenCode，强制）

本节整体为必做步骤。统一使用相同的记忆文件与行为契约。建议在宿主实际读取的全局 steering 文件（支持时为 `AGENTS.md`）维护主版本；若平台不读取该文件，在其原生全局 steering 文件中镜像同样内容。该映射是强制要求，不是建议项。

### Claude Code

1. 将该技能目录放入 Claude Code 的 skills 路径。
2. 必须在 Claude Code 实际读取的全局 `CLAUDE.md` 中加入（或镜像）以下契约；否则不得认为该技能已在 Claude Code 中生效：

```markdown
## Self-Improving Runtime Contract
- At start of each task, load `~/self-improving/memory.md` (HOT) first.
- On explicit correction, append to `corrections.md` and update promotion counters.
- After significant work, run self-reflection and log lessons.
- On memory commands, query tiered files and cite sources.
```

### Codex

1. 保持本技能在工作区技能路径（例如 `./skills/self-improving-cn`）。
2. 必须在 Codex 实际读取的全局 steering 文件（支持时为 `AGENTS.md`）写入契约；只有在项目本地 `AGENTS.md` 就是运行时真实入口时，它才算有效。缺少这一步时，不得认为该技能已在 Codex 中生效：

```markdown
## Self-Improving Runtime Contract
- Start: load `~/self-improving/memory.md`, then `index.md`, then matching namespace files.
- Correction: write event to `~/self-improving/corrections.md` with timestamp + context.
- Reflection: after multi-step tasks, log lesson and promote only after confirmation rules.
- Transparency: cite memory source when behavior is affected.
```

### Gemini

1. 在 Gemini 实际使用的全局 `GEMINI.md` 或系统提示文件中引用本技能。
2. 必须写入同一契约文本；否则不得认为该技能已在 Gemini 中生效：

```markdown
## Self-Improving Runtime Contract
- Use `~/self-improving` as fixed memory root.
- Always load HOT memory first.
- Record explicit corrections only; never infer from silence.
- Apply tier precedence: project > domain > global.
- Expose source and support forget/export commands.
```

### OpenCode

1. 在 OpenCode 宿主实际使用的全局代理指令文件中引用本技能。
2. 必须复用同一契约；否则不得认为该技能已在 OpenCode 中生效：

```markdown
## Self-Improving Runtime Contract
- Use `~/self-improving` as fixed memory root.
- Load HOT memory before generating responses.
- Log explicit corrections to `corrections.md` with timestamp and context.
- Apply namespace precedence: project > domain > global.
- Cite memory source when it changes behavior.
```

### 兼容说明

- 记忆格式为纯 Markdown，不依赖平台特定解析器。
- 本技能不需要网络访问。
- 若运行时没有原生 skill tool，可在会话开始先加载 `SKILL.md`，再按同一 steering 契约执行。

## 验证

使用以下两类校验共同确认 setup 已完成。

1. 执行 `memory stats`，确认记忆根目录可用，结果应类似：

```
📊 Self-Improving Memory

🔥 HOT (always loaded):
   memory.md: 0 entries

🌡️ WARM (load on demand):
   projects/: 0 files
   domains/: 0 files

❄️ COLD (archived):
   archive/: 0 files

⚙️ Mode: Passive
```

2. 校验当前生效的全局宿主 steering 文件，确认其中已经写入全部必需的 `self-improving` 集成内容。除非运行时真的读取项目本地文件，否则不要拿项目本地 steering 文件做验收。

最低通过标准：
- steering 文件中存在 `## Self-Improving Mode` 配置块
- steering 文件中存在 `## Self-Improving Runtime Contract` 配置块
- steering 文件的 `## Memory` 段中包含 `Self-improving: ~/self-improving/` 连续性条目
- steering 文件的记忆规则已将纠错、偏好、工作流/风格选择、经验教训路由到 `~/self-improving/`

只要上述任一项缺失，即使 `memory stats` 成功，也应判定 setup 未完成。

## 可选：Heartbeat 集成

在 `HEARTBEAT.md` 增加：

```markdown
## Self-Improving Check

- [ ] Review corrections.md for patterns ready to graduate
- [ ] Check memory.md line count (should be ≤100)
- [ ] Archive patterns unused >90 days
```
