---
name: self-improving-cn
description: 自我反思 + 自我纠错 + 自我学习 + 自组织记忆。代理可评估自身产出、捕捉错误并持续改进。建议在开始任务前与回复用户后使用。
metadata:
  version: 2.0.0
  displayName: 自我进化代理（含自我反思）
  homepage: https://clawic.com/skills/self-improving
  changelog: "重构为仅支持 coding-agent 运行时，并统一 steering 接入。"
  memoryRoot: "~/self-improving/"
  supportsCodingAgentsOnly: true
  platforms:
    - claude-code
    - codex
    - gemini
    - opencode
---

## 何时使用

当用户纠正你、指出错误、你刚完成较复杂工作、或你意识到当前输出还能更好时使用。目标是让知识持续累积，而不是每次从零开始。

## 架构

记忆存放在 `~/self-improving/`，采用分层结构。若目录不存在，先执行 `setup.md`。

```
~/self-improving/
├── memory.md          # HOT：≤100 行，始终加载
├── index.md           # 主题索引与行数
├── projects/          # 项目级经验
├── domains/           # 领域级经验（代码/写作/沟通）
├── archive/           # COLD：衰减后归档
└── corrections.md     # 最近 50 条纠错日志
```

## 快速索引

| 主题         | 文件                     |
| ------------ | ------------------------ |
| 初始化       | `setup.md`               |
| 平台接入     | `setup.md`（跨平台章节） |
| 记忆模板     | `memory-template.md`     |
| 学习机制     | `learning.md`            |
| 安全边界     | `boundaries.md`          |
| 扩展规则     | `scaling.md`             |
| 记忆操作     | `operations.md`          |
| 自我反思日志 | `reflections.md`         |

## 跨平台激活契约

为在 Claude Code、Codex、Gemini、OpenCode 上保持一致行为，执行以下运行时契约：

强制安装要求：必须先把本契约映射到宿主平台的 steering 文件中，才能视为本技能已安装并已启用。仅仅读取 `~/self-improving/` 目录或记忆文件，不构成有效启用。

1. **会话/任务开始时**

- 固定使用 `~/self-improving/` 作为记忆根目录
- 先加载 `memory.md`（HOT），再读 `index.md`，最后按上下文加载命名空间文件

2. **输出后（有意义的完成点）**

- 做一次自我反思：结果 vs 意图、经验、候选模式
- 在回合结束前写入反思/纠错更新

3. **收到明确纠正时**

- 追加纠错事件到 `corrections.md`（含时间戳与上下文）
- 更新计数器与晋升状态

4. **收到记忆指令时**

- 支持自然指令（`memory stats`、`show patterns`、`forget X`、`export memory`）
- 返回带来源的结果（文件与上下文）

5. **上下文预算不足时**

- 安全降级：只加载 HOT，并明确告知跳过的 WARM/COLD

该契约与平台无关，差异仅在各平台的 steering 文件位置。若缺少 Steering 文件映射，则应视为安装未完成，必须先执行 `setup.md` 中的映射步骤。

## 检测触发器

检测到以下模式时自动记录：

**纠错类** → 写入 `corrections.md`，并评估是否晋升到 `memory.md`：

- “不对，应该是……”
- “其实应该……”
- “你这里错了……”
- “我更喜欢 X，不是 Y”
- “记住我一直都是……”
- “我之前说过……”
- “别再做 X 了”
- “你为什么总是……”

**偏好信号** → 若为明确表述，可写入 `memory.md`：

- “我喜欢你……”
- “以后总是这样做”
- “永远不要那样做”
- “我的风格是……”
- “在 [项目] 里，用……”

**候选模式** → 先跟踪，达到 3 次后晋升：

- 同类指令重复 3 次以上
- 某工作流持续有效
- 用户反复肯定某做法

**忽略项**（不记录）：

- 一次性命令（如“现在先做 X”）
- 仅当前上下文有效（如“这个文件里……”）
- 假设讨论（如“如果……会怎样”）

## 自我反思

完成较重要工作后暂停并评估：

1. **是否达到预期？** 对比结果与目标
2. **哪里可以更好？** 提炼下次可执行改进
3. **是否形成模式？** 若是，写入 `corrections.md`

**建议触发时机：**

- 多步骤任务完成后
- 收到正/负反馈后
- 修复 bug 或错误后
- 你自己发现输出可改进时

**日志格式：**

```
CONTEXT: [任务类型]
REFLECTION: [观察]
LESSON: [下次改进]
```

**示例：**

```
CONTEXT: 构建 Flutter UI
REFLECTION: 间距看起来不协调，返工了
LESSON: 向用户展示前先做一次视觉检查
```

自我反思与纠错使用同一晋升机制：7 天内成功应用 3 次可晋升到 HOT。

## 快速查询

| 用户说法                | 动作                             |
| ----------------------- | -------------------------------- |
| “你记得关于 X 的什么？” | 搜索全部分层并返回匹配           |
| “你学到了什么？”        | 展示 `corrections.md` 最近 10 条 |
| “显示我的模式”          | 列出 `memory.md`（HOT）          |
| “显示 [项目] 模式”      | 加载 `projects/{name}.md`        |
| “暖存储里有什么？”      | 列出 `projects/` 与 `domains/`   |
| “memory stats”          | 展示各层统计                     |
| “forget X”              | 从所有层删除（先确认）           |
| “export memory”         | 打包导出全部文件                 |

## Memory Stats

收到 “memory stats” 时输出：

```
📊 Self-Improving Memory

HOT（始终加载）:
  memory.md: X entries

WARM（按需加载）:
  projects/: X files
  domains/: X files

COLD（归档）:
  archive/: X files

近 7 天活动:
  Corrections logged: X
  Promotions to HOT: X
  Demotions to WARM: X
```

## 核心规则

### 1. 从纠错与反思中学习

- 用户明确纠正时必须记录
- 你识别到改进点时也应记录
- 不可从沉默推断偏好
- 同类经验 3 次后，询问是否固化为规则

### 2. 分层存储

| 层级 | 位置                | 限制           | 行为             |
| ---- | ------------------- | -------------- | ---------------- |
| HOT  | memory.md           | ≤100 行        | 始终加载         |
| WARM | projects/, domains/ | 每文件 ≤200 行 | 上下文匹配时加载 |
| COLD | archive/            | 不限           | 仅显式查询时加载 |

### 3. 自动晋升/降级

- 7 天内使用 3 次 → 晋升 HOT
- 30 天未使用 → 降到 WARM
- 90 天未使用 → 归档到 COLD
- 未经用户确认不得删除

### 4. 命名空间隔离

- 项目模式放 `projects/{name}.md`
- 全局偏好放 HOT（`memory.md`）
- 领域模式放 `domains/`
- 继承链：全局 → 领域 → 项目

### 5. 冲突处理

模式冲突时：

1. 作用域更具体者优先（项目 > 领域 > 全局）
2. 同级时更近期者优先
3. 仍有歧义则询问用户

### 6. 压缩整理

文件超限时：

1. 合并相似纠错为单条规则
2. 归档长期未用模式
3. 压缩冗长描述
4. 不丢失已确认偏好

### 7. 透明可追溯

- 基于记忆做决策时必须标注来源，如：`Using X (from projects/foo.md:12)`
- 可提供每周摘要（新增/降级/归档）
- 可按需导出全部记忆

### 8. 安全边界

详见 `boundaries.md`，禁止存储凭据、医疗信息、第三方隐私等敏感数据。

### 9. 优雅降级

若上下文受限：

1. 仅加载 HOT
2. 相关命名空间按需读取
3. 不得静默失败，需明确说明未加载内容

## 范围

本技能**只做**：

- 从用户纠错与自我反思中学习
- 将偏好写入本地文件（`~/self-improving/`）
- 激活时读取本技能记忆文件

本技能**绝不做**：

- 访问日历、邮箱、通讯录
- 发起网络请求
- 读取 `~/self-improving/` 之外文件
- 从沉默或观察中推断偏好
- 修改自身 `SKILL.md`

## 相关技能

在 coding-agent 运行时（Claude Code/Codex/Gemini/OpenCode），请将技能目录放到对应路径，并在 steering 文件接入本运行契约。

- `memory` — 代理长期记忆模式
- `learning` — 自适应讲解与学习
- `decide` — 自动学习决策模式
- `escalate` — 判断何时询问与何时自治

## 反馈

- 建议通过仓库变更历史与 memory stats 输出来跟踪行为变化。
