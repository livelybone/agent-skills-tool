# 记忆操作

## 用户命令

| 命令 | 动作 |
|------|------|
| "What do you know about X?" | 搜索全部层并返回带来源匹配 |
| "Show my memory" | 展示 `memory.md` 内容 |
| "Show [project] patterns" | 加载并展示指定命名空间 |
| "Forget X" | 从全部层删除并先确认 |
| "Forget everything" | 全量清空（可先导出） |
| "What changed recently?" | 展示最近 20 条纠错 |
| "Export memory" | 生成可下载归档 |
| "Memory status" | 展示层级大小、最近压缩、健康状态 |

## 自动化操作

### 会话开始时
1. 加载 `memory.md`（HOT）
2. 检查 `index.md` 获取上下文提示
3. 若检测到项目上下文，预加载对应命名空间

### 收到纠错时
```
1. 解析纠错类型（preference / pattern / override）
2. 检查是否重复（任意层已存在）
3. 若为新条目：
   - 写入 corrections.md（带时间戳）
   - 增加纠错计数
4. 若为重复：
   - 递增计数并更新时间
   - 若计数 >= 3：询问是否固化规则
5. 判定命名空间（global / domain / project）
6. 写入对应文件
7. 更新 index.md 行数
```

### 匹配并应用模式时
```
1. 定位模式来源（file:line）
2. 应用模式
3. 引用来源："Using X (from memory.md:15)"
4. 记录使用次数供衰减判断
```

### 每周维护（Cron）
```
1. 扫描全部文件找衰减候选
2. 将 >30 天未使用的移到 WARM
3. 将 >90 天未使用的归档到 COLD
4. 任意文件超限则压缩
5. 更新 index.md
6. 生成每周摘要（可选）
```

## 文件格式

### memory.md（HOT）
```markdown
# Self-Improving Memory

## Confirmed Preferences
- format: bullet points over prose (confirmed 2026-01)
- tone: direct, no hedging (confirmed 2026-01)

## Active Patterns
- "looks good" = approval to proceed (used 15x)
- single emoji = acknowledged (used 8x)

## Recent (last 7 days)
- prefer SQLite for MVPs (corrected 02-14)
```

### corrections.md
```markdown
# Corrections Log

## 2026-02-15
- [14:32] Changed verbose explanation → bullet summary
  Type: communication
  Context: Telegram response
  Confirmed: pending (1/3)

## 2026-02-14
- [09:15] Use SQLite not Postgres for MVP
  Type: technical
  Context: database discussion
  Confirmed: yes (said "always")
```

### projects/{name}.md
```markdown
# Project: my-app

Inherits: global, domains/code

## Patterns
- Use Tailwind (project standard)
- No Prettier (eslint only)
- Deploy via GitLab CI

## Overrides
- semicolons: yes (overrides global no-semi)

## History
- Created: 2026-01-15
- Last active: 2026-02-15
- Corrections: 12
```

## 边界场景处理

### 发现冲突
```
Pattern A: "Use tabs" (global, confirmed)
Pattern B: "Use spaces" (project, corrected today)

Resolution:
1. 项目覆盖全局 → 当前项目使用 spaces
2. 在 corrections.md 记录冲突
3. 询问："spaces 只用于这个项目，还是全局生效？"
```

### 用户改主意
```
Old: "Always use formal tone"
New: "Actually, casual is fine"

Action:
1. 给旧模式打时间戳并归档
2. 新模式先作为 tentative
3. 保留历史参考（"你之前偏好 formal"）
```

### 上下文不明确
```
User says: "Remember I like X"

But which namespace?
1. 看当前上下文（project? domain?）
2. 仍不清晰则问："全局生效还是仅当前场景？"
3. 默认落到当前最具体激活上下文
```
