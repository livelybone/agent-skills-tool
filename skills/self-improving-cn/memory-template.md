# 记忆模板

首次使用时，将以下结构复制到 `~/self-improving/memory.md`。

```markdown
# Self-Improving Memory

## Confirmed Preferences
<!-- 用户确认的模式，不自动衰减 -->

## Active Patterns
<!-- 观察到 3+ 次的模式，可衰减 -->

## Recent (last 7 days)
<!-- 新纠错，待确认 -->
```

## 初始目录结构

首次激活时创建：

```bash
mkdir -p ~/self-improving/{projects,domains,archive}
touch ~/self-improving/{memory.md,index.md,corrections.md}
```

## 索引模板

用于 `~/self-improving/index.md`：

```markdown
# Memory Index

## HOT
- memory.md: 0 lines

## WARM
- (no namespaces yet)

## COLD
- (no archives yet)

Last compaction: never
```

## 纠错日志模板

用于 `~/self-improving/corrections.md`：

```markdown
# Corrections Log

<!-- Format:
## YYYY-MM-DD
- [HH:MM] Changed X → Y
  Type: format|technical|communication|project
  Context: where correction happened
  Confirmed: pending (N/3) | yes | no
-->
```
