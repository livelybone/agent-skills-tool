# HOT 记忆 —— 模板

> 首次启用技能时创建于 `~/self-improving/memory.md`。
> 保持 ≤100 行。高频模式应放在这里。

## 示例条目

```markdown
## Preferences
- Code style: Prefer explicit over implicit
- Communication: Direct, no fluff
- Time zone: Europe/Madrid

## Patterns (promoted from corrections)
- Always use TypeScript strict mode
- Prefer pnpm over npm
- Format: ISO 8601 for dates

## Project defaults
- Tests: Jest with coverage >80%
- Commits: Conventional commits format
```

## 使用方式

代理会：
1. 每个会话都加载该文件
2. 当模式在 7 天内使用 3 次时新增条目
3. 30 天未使用时降到 WARM
4. 自动压缩，确保不超过 100 行
