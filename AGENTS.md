# Agent Skills Tool - Agent指南

## 项目概述
这是一个跨平台的Agent Skills安装工具，支持将技能安装到Codex、Claude Code和Gemini CLI环境中。该工具允许用户在全局（用户范围）或特定项目中安装、删除和管理技能。

## 基本命令
- `npm run typecheck` - 运行TypeScript类型检查而不发出JavaScript
- `npm run build` - 将TypeScript源代码编译为JavaScript到`dist`目录
- `npm run prepublishOnly` - 运行类型检查和构建（在npm发布前自动使用）

## 代码组织
- 源代码：`src/index.ts` - 使用Commander.js构建的主CLI入口点
- 技能：存储在`skills/`目录中，每个技能包含：
  - `SKILL.md` - 必需文件，包含YAML前置元数据（名称、描述）
  - 可选的引用、脚本、模板和其他技能特定文件
- 配置：`package.json`，`tsconfig.json`
- 内存：`memory/`目录用于存储操作数据（由自我改进技能使用）

## 命名约定和样式
- 使用严格类型检查的TypeScript
- 变量、函数和参数使用camelCase
- TypeScript接口和类型使用PascalCase
- 目录和文件名使用kebab-case（例如：`multi-agent-loop`，`self-improving`）
- SKILL.md文件中的YAML前置元数据用于技能元数据
- 注释样式：函数使用JSDoc，复杂逻辑使用内联注释

## 测试方法
- 未配置专用测试框架
- 通过`tsc --noEmit`（类型检查脚本）强制执行类型安全
- 通过技能安装和使用进行手动验证
- 未显式配置linting

## 重要的注意事项和非明显模式
1. **多目标安装**：该工具同时安装到三个不同的代理环境中：
   - Codex：`$CODEX_HOME/skills` 或 `{project}/.codex/skills`
   - Claude Code：`~/.claude/skills` 或 `{project}/.claude/skills`
   - Gemini CLI：`~/.gemini/skills` 或 `{project}/.gemini/skills`

2. **冲突解决**：当安装已存在的技能时：
   - 没有`--force`或`--merge`：提示用户选择操作（覆盖/合并/跳过）
   - `--force`：完全覆盖现有目录
   - `--merge`：合并目录，仅覆盖冲突文件

3. **技能来源**：技能可以从以下位置安装：
   - 本地目录路径
   - 本地SKILL.md文件
   - GitHub仓库（通过`owner/repo`或完整URL）
   - 使用`--subdir`指定GitHub子目录
   - 使用`--ref`指定特定的git ref/标签/分支

4. **前置元数据要求**：每个SKILL.md必须包含YAML前置元数据，包含：
   - `name`：技能标识符（用于目录命名）
   - `description`：技能目的描述
   - 如果目录名与前置元数据名称不匹配，则会发出警告

5. **Node.js版本**：需要Node.js >=18（在package.json的engines中强制执行）

6. **内存系统**：自我改进技能使用存储在`memory/`目录中的内存系统，包含：
   - 每日Markdown文件（YYYY-MM-DD.md）
   - 内存结构的模板文件
   - 支持文档（boundaries.md，corrections.md等）

## 技能结构
```
skill-name/
├── SKILL.md (必需 - 包含YAML前置元数据)
├── scripts/ (可选 - 安装/执行脚本)
├── templates/ (可选 - 模板文件)
├── references/ (可选 - 参考文档)
└── ... (其他技能特定文件)
```

SKILL.md前置元数据示例：
```yaml
---
name: code-reviewer
description: 使用团队标准审查代码。
---
```

## 开发设置
1. 安装依赖：`npm install`
2. 类型检查：`npm run typecheck`
3. 构建：`npm run build`
4. 发布准备：`npm run prepublishOnly`

## CLI使用模式
- 从本地路径安装：`agent-skills-tool -i /path/to/skill`
- 从GitHub安装：`agent-skills-tool -i owner/repo`
- 带子目录安装：`agent-skills-tool -i owner/repo --subdir path/to/skill`
- 删除技能：`agent-skills-tool -r skill-name`
- 项目特定安装：提供目标路径作为参数
- 强制覆盖：添加`--force`标志
- 合并模式：添加`--merge`标志