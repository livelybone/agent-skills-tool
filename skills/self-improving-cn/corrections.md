# 纠错日志 —— 模板

> 首次启用技能时创建于 `~/self-improving/corrections.md`。
> 保留最近 50 条纠错。更早内容会评估晋升或归档。

## 示例

```markdown
## 2026-02-19

### 14:32 — Code style
- **Correction:** "Use 2-space indentation, not 4"
- **Context:** Editing TypeScript file
- **Count:** 1 (first occurrence)

### 16:15 — Communication
- **Correction:** "Don't start responses with 'Great question!'"
- **Context:** Chat response
- **Count:** 3 → **PROMOTED to memory.md**

## 2026-02-18

### 09:00 — Project: website
- **Correction:** "For this project, always use Tailwind"
- **Context:** CSS discussion
- **Action:** Added to projects/website.md
```

## 日志格式

每条包含：
- **Timestamp** —— 发生时间
- **Correction** —— 用户纠正内容
- **Context** —— 触发场景
- **Count** —— 出现次数（用于晋升）
- **Action** —— 最终写入位置（如已晋升）
