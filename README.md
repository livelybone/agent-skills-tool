# agent-skills-tool

一个跨平台的 Agent Skills 安装工具，支持 Codex / Claude Code / Gemini CLI。

## 安装

```bash
npm i -g agent-skills-tool
```

## 开发

```bash
npm run typecheck
npm run build
```

## 用法

```bash
agent-skills-tool -i /path/to/skill
agent-skills-tool -i /path/to/skill /path/to/project
agent-skills-tool -i https://github.com/owner/repo --subdir skills/my-skill
agent-skills-tool -i owner/repo --subdir skills/my-skill
agent-skills-tool -i https://github.com/owner/repo/tree/main/skills/my-skill
```

### 冲突处理

- `--force` 覆盖已有目录
- `--merge` 合并并覆盖同名文件
- 不加参数会交互式选择（覆盖 / 合并 / 取消）

### 从 Git 仓库安装

- 支持 GitHub URL 或 `owner/repo` 简写
- 仓库内非根目录的 Skill 用 `--subdir` 指定
- 可用 `--ref` 指定分支或 tag
- 需要本机已安装 `git`

## 安装位置

### 全局（不传 `destination_project_path`）
- Codex: `$CODEX_HOME/skills`（默认 `~/.codex/skills`）
- Claude Code: `~/.claude/skills`
- Gemini CLI: `~/.gemini/skills`

### 项目级（传 `destination_project_path`）
- Codex: `{project}/.codex/skills`
- Claude Code: `{project}/.claude/skills`
- Gemini CLI: `{project}/.gemini/skills`

## SKILL.md 要求

- 必须包含 YAML frontmatter
- 必填字段：`name`、`description`、`metadata.version`
- `metadata.version` 必须为 semver（例如 `1.2.3`）

示例：

```md
---
name: code-reviewer
description: Reviews code using team standards.
metadata:
  version: 1.0.0
---

# Code Reviewer
...
```
