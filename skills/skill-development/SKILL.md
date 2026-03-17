---
name: skill-development
description: Skill 开发规范文档；定义边界规则、标准结构、内联策略与质量标准
metadata:
  version: 1.0.0
---

# Skill 开发规范

## 适用场景
- 查阅 Skill 编写规范与标准
- 理解 SKILL 边界规则（什么放全局、什么放 skill、什么放 references）
- 学习 SKILL.md 标准结构与最佳实践
- 评审现有 Skill 质量是否符合规范

> 注：本 skill 提供**规范文档**，不负责实际创建 skill 文件。创建 skill 请使用 agent 提供的 skill-creator 等工具。

## 必须材料
无特定材料要求，本 skill 为纯参考文档。

## 执行步骤

本 skill 是参考文档，无需"执行"，按需查阅即可：

### 开发前查阅
- **边界规则**：见 references/complete-guide.md#边界规则
  - 什么放全局上下文（GEMINI.md 等）
  - 什么放 SKILL.md
  - 什么放 references/
  - 什么放 assets/

- **标准结构**：见下方"产物与格式"
  - frontmatter 必填字段
  - 9 个小节的顺序与用途

### 开发中参考
- **内联策略**（建议）：见 references/complete-guide.md#内联策略
  - < 20 行：建议完全内联
  - 20-50 行：建议内联核心 + 引用详细
  - \> 50 行：建议仅引用（保持 SKILL.md 简洁）

- **引用全局规范**：见 references/complete-guide.md#引用全局规范
  - 如何引用全局上下文的通用规范
  - 如何引用全局的验证方式

### 开发后评审
- **质量检查清单**：见下方"质量门槛"
  - frontmatter 检查
  - 结构检查
  - 内容检查
  - 文件组织检查

## 产物与格式

### SKILL.md 标准结构

**frontmatter**（必需）：
```yaml
---
name: <skill-name>           # kebab-case，与目录名一致
description: <简短描述>      # < 80 字，触发场景/输出产物
metadata:
  version: 1.0.0             # semver 格式
---
```

**正文 9 个小节**（按顺序）：

1. **适用场景**
   - 列出 2-4 个典型触发场景
   - 说明何时应该使用该 skill

2. **必须材料**
   - 列出执行该 skill 需要的输入
   - 包括配置文件、依赖信息、上下文要求

3. **执行步骤**
   - 按顺序列出操作步骤
   - 如有多个场景，分别说明
   - 使用编号列表

4. **产物与格式**
   - 明确输出内容
   - 提供模板或示例
   - 说明验收标准

5. **质量门槛**
   - **必须引用全局上下文的通用规范**
   - 列出该 skill 特定的检查项
   - 内联高频检查项（< 20 行）

6. **验证方式**
   - **必须引用全局上下文的"验证方式通用流程"**
   - 说明该 skill 特定的验证方式

7. **不覆盖范围**
   - 明确该 skill 不负责的事项

8. **覆盖声明**（可选）
   - 仅在需要覆盖全局规则时填写

9. **引用资料**
   - 列出 references/ 和 assets/ 中的文件

### 目录结构规范

```
skills/<skill-name>/
├── SKILL.md                # 必需
├── references/             # 可选
│   └── detailed-guide.md   # 详细说明（> 50 行）
└── assets/                 # 可选
    └── templates/          # 模板文件
```

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"

### SKILL.md 核心要求（内联）

**frontmatter 检查**：
- [ ] `name` 唯一且与目录名一致（kebab-case）
- [ ] `description` 简洁（< 80 字）且包含触发场景与输出
- [ ] `metadata.version` 符合 semver 格式（major.minor.patch）

**结构检查**：
- [ ] 包含所有必需小节（除"覆盖声明"可选）
- [ ] 使用中文小节标题
- [ ] 小节顺序符合标准（1-9）

**内容检查**：
- [ ] "质量门槛"引用了全局上下文规范（如"代码质量基础规范"）
- [ ] "验证方式"引用了全局"验证方式通用流程"
- [ ] 执行步骤清晰可操作
- [ ] 产物格式有明确示例

**内联策略检查**（建议）：
- [ ] 简短内容（< 20 行）优先内联，保持可读性
- [ ] 中等内容（20-50 行）可内联核心 + 引用详细
- [ ] 长内容可引用 references/，避免 SKILL.md 过长

详细的质量检查清单与说明见 `references/complete-guide.md`

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定的验证

本 skill 是纯文档，无需验证。

使用本规范编写的 SKILL.md 可通过以下方式验证：
1. 对照质量检查清单逐项检查
2. 使用工具（如 gray-matter）解析 frontmatter 格式
3. 检查文件组织（目录名、引用路径）
4. 在实际项目中安装并测试该 skill

## 不覆盖范围
- 不负责实际创建 skill 文件或目录（应使用 skill-creator 等工具）
- 不负责 skill 的具体业务逻辑（由 skill 本身定义）
- 不负责 skill 的版本发布与分发
- 不负责 agent 底层对 skill 的解析机制
- 不提供自动化验证工具或 CI/CD 集成

## 覆盖声明
无

## 引用资料
- `references/complete-guide.md`（完整的开发指南，包含边界规则、内联策略、示例、常见问题）
