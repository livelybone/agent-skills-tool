# 扩展策略

## 规模阈值

| 规模 | 条目数 | 策略 |
|------|--------|------|
| Small | <100 | 单一 `memory.md`，不分命名空间 |
| Medium | 100-500 | 拆分到 `domains/`，维护基础索引 |
| Large | 500-2000 | 完整命名空间层级，积极压缩 |
| Massive | >2000 | 按年份归档，HOT 仅保留摘要 |

## 何时拆分

满足任一条件就新建命名空间文件：
- 单文件超过 200 行
- 某主题纠错数超过 10 条
- 用户明确分离上下文（如“工作场景…”、“这个项目里…”）

## 压缩规则

### 合并相似纠错
```
BEFORE (3 entries):
- [02-01] Use tabs not spaces
- [02-03] Indent with tabs
- [02-05] Tab indentation please

AFTER (1 entry):
- Indentation: tabs (confirmed 3x, 02-01 to 02-05)
```

### 压缩冗长模式
```
BEFORE:
- When writing emails to Marcus, use bullet points, keep under 5 items,
  no jargon, bottom-line first, he prefers morning sends

AFTER:
- Marcus emails: bullets ≤5, no jargon, BLUF, AM preferred
```

### 带上下文归档
移入 COLD 时：
```
## Archived 2026-02

### Project: old-app (inactive since 2025-08)
- Used Vue 2 patterns
- Preferred Vuex over Pinia
- CI on Jenkins (deprecated)

Reason: Project completed, patterns unlikely to apply
```

## 索引维护

`index.md` 追踪全部命名空间：
```markdown
# Memory Index

## HOT (always loaded)
- memory.md: 87 lines, updated 2026-02-15

## WARM (load on match)
- projects/current-app.md: 45 lines
- projects/side-project.md: 23 lines
- domains/code.md: 112 lines
- domains/writing.md: 34 lines

## COLD (archive)
- archive/2025.md: 234 lines
- archive/2024.md: 189 lines

Last compaction: 2026-02-01
Next scheduled: 2026-03-01
```

## 多项目模式

### 继承链
```
global (memory.md)
  └── domain (domains/code.md)
       └── project (projects/app.md)
```

### 覆盖语法
在项目文件中：
```markdown
## Overrides
- indentation: spaces (overrides global tabs)
- Reason: Project eslint config requires spaces
```

### 冲突检测
加载时执行：
1. 构建继承链
2. 检测冲突
3. 具体作用域优先
4. 记录冲突以便后续审查

## 用户类型适配

| 用户类型 | 记忆策略 |
|----------|----------|
| Power user | 激进学习，少确认 |
| Casual | 保守学习，多确认 |
| Team shared | 按用户隔离命名空间，共享项目空间 |
| Privacy-focused | 本地存储、敏感类别显式同意 |

## 恢复策略

### 上下文丢失
如果代理中途丢失上下文：
1. 重新读取 `memory.md`
2. 查看 `index.md` 查找相关命名空间
3. 加载活跃项目命名空间
4. 继续执行

### 文件损坏恢复
如果记忆文件损坏：
1. 从 `archive/` 查最近备份
2. 用 `corrections.md` 重建
3. 让用户重新确认关键偏好
4. 记录事故用于排障
