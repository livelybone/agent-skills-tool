# Agent Skills 开发指南

本文档为 SKILL 开发者提供指导，定义了如何组织和编写高质量的 Agent Skills。

---

## 一、SKILL 边界规则

### 什么放全局上下文（GEMINI.md）
- 长期稳定的原则（安全、正确性、效率优先级）
- 通用规范（代码质量、复用流程、架构一致性）
- 所有 skill 都需要的检查清单规则
- 通用验证流程
- SKILL 加载策略
- 交互协议

### 什么放 SKILL.md
- 任务级流程步骤
- 具体的输入输出格式
- 该 skill 特定的检查项（核心部分）
- 适用场景说明
- 产物模板与示例

### 什么放 references/
- 详细检查清单（较长内容，建议 > 50 行时提取）
- 技术栈特定规范（如 `js-jest.md`、`python-pytest.md`）
- 语言特定的最佳实践
- 详细的配置说明

### 什么放 assets/
- 模板文件（如测试模板、配置模板）
- 示例代码
- 可复用的代码片段

---

## 二、SKILL.md 标准结构

### frontmatter 规范
```yaml
---
name: <skill-name>           # 必填，唯一标识，使用 kebab-case
description: <简短描述>      # 必填，包含触发场景与输出，一行
metadata:
  version: 1.0.0             # 必填，semver 格式
---
```

**frontmatter 要求**：
- `name`：全局唯一，与目录名一致，使用 kebab-case
- `description`：简短描述（建议 < 80 字），包含：
  - 触发场景（何时使用）
  - 主要输出（产出什么）
- `metadata.version`：遵循 semver 规范（major.minor.patch）

### 正文小节（按顺序）

1. **适用场景**
   - 明确列出触发条件
   - 说明何时应该使用该 skill
   - 给出 2-4 个典型场景

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
   - 说明产物的验收标准

5. **质量门槛**
   - 引用全局上下文的通用规范（必须）
   - 列出该 skill 特定的检查项
   - 简短检查项可内联（建议 < 20 行）
   - 详细检查清单可引用 references/

6. **验证方式**
   - 引用全局上下文的"验证方式通用流程"（必须）
   - 说明该 skill 特定的验证命令或方式
   - 明确验证通过的标准

7. **不覆盖范围**
   - 明确该 skill 不负责的事项
   - 避免范围蔓延

8. **覆盖声明**（可选）
   - 仅在需要覆盖全局规则时填写
   - 必须说明原因与替代方案
   - 格式：`覆盖项：<全局规则名>`、`理由：<原因>`、`替代验证：<方案>`

9. **引用资料**
   - 列出 references/ 中的相关文档
   - 列出 assets/ 中的模板文件
   - 使用相对路径

---

## 三、内联策略（建议）

### 内容长度决策

| 长度 | 建议策略 | 示例 |
|------|---------|------|
| < 20 行 | 建议完全内联到 SKILL.md | 核心检查清单（5-10 项） |
| 20-50 行 | 建议内联核心摘要 + 引用完整文档 | 测试用例覆盖度要求（内联核心 3 点，详细见 references） |
| > 50 行 | 建议仅引用（保持 SKILL.md 简洁） | OWASP Top 10 详细说明 |

> 注：这是建议性策略，不是强制要求。根据实际情况灵活调整。

### 内联示例

**完全内联**（< 20 行）：
```markdown
## 质量门槛

### 用例覆盖度
- **正常路径**：至少 1 个主流程用例
- **边界条件**：空值、零值、最大值、最小值
- **失败路径**：异常输入、依赖失败
```

**部分内联**（20-50 行）：
```markdown
## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"

### 安全检查（核心）
- 无硬编码密码、token
- 无 SQL 注入、XSS 漏洞
- 敏感数据已脱敏

详细的 OWASP Top 10 检查清单见 `references/security-checklist.md`
```

**仅引用**（> 50 行）：
```markdown
## 质量门槛

详见 `references/comprehensive-checklist.md`
```

---

## 四、引用全局规范的方式

### 标准引用格式

```markdown
## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"
> 遵循全局上下文中的"复用优先流程"
> 遵循全局上下文中的"架构一致性原则"

### 本 skill 特定的检查项
- 检查项 1
- 检查项 2
```

### 验证方式引用

```markdown
## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定的验证
- 运行测试：先发现测试命令（如 `npm test`、`pytest`），然后执行
- 检查覆盖率：确保 ≥ 80%
```

---

## 五、完整示例

### 示例：unit-test/SKILL.md

```markdown
---
name: unit-test
description: 编写单元测试/评审单元测试/补测与测试先行；输出测试用例与结果
metadata:
  version: 1.0.0
---

# 单元测试标准

## 适用场景
- 为已有代码补充单元测试
- 测试先行开发（TDD）
- 评审现有测试代码质量

## 必须材料
- 被测模块与行为期望
- 依赖与 mock 约束
- 项目既有测试栈与命令（如 Jest、pytest、JUnit）

## 执行步骤

### 场景 A：为已有代码补测
1. 梳理现有行为、边界条件与依赖
2. 设计最小可行用例集合（正常路径/边界条件/失败路径）
3. 必要时进行可测性改造（依赖注入/拆分纯函数）
4. 编写并运行测试，修正测试或实现代码

### 场景 B：测试先行（新需求/功能）
1. 先输出用例清单与断言说明
2. 依据用例实现测试代码
3. 再编写功能代码
4. 运行测试并迭代修复，直到全部通过

## 产物与格式
- **测试用例清单**：given/when/then 结构
- **测试代码文件**：
  - TypeScript/JavaScript：如 `<module>.test.ts` 或 `<module>.spec.ts`
  - Python：如 `test_<module>.py`
  - Java：如 `<Module>Test.java`
- **测试评审结论**（如适用）

## 质量门槛

> 遵循全局上下文中的"代码质量基础规范"

### 用例覆盖度
- **正常路径**：至少 1 个主流程用例
- **边界条件**：空值、零值、最大值、最小值
- **失败路径**：异常输入、依赖失败

### 测试独立性
- 每个测试用例可独立运行
- 不依赖执行顺序
- 使用固定夹具（fixture），避免随机数据

### 命名清晰度
- 测试函数名描述行为：`test_<function>_<scenario>_<expected>`
- 示例：`test_getUserData_whenUserNotFound_returnsNull`

详细检查清单见 `references/general-standards.md`

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定的验证
- **运行测试**：先发现测试命令（如 `npm test`、`pytest`），然后执行
- **检查覆盖率**：先发现覆盖率命令（如 `npm run coverage`），确保 ≥ 80%
- **所有测试通过**：退出码必须为 0

## 不覆盖范围
- 集成测试或 E2E 测试（除非明确要求）
- 性能测试、压力测试

## 覆盖声明
无

## 引用资料
- `references/general-standards.md`（通用测试标准）
- `references/js-jest.md`（JavaScript/TypeScript 特定）
- `references/python-pytest.md`（Python 特定）
- `references/java-junit.md`（Java 特定）
- 模板：`assets/templates/jest.test.ts`、`assets/templates/pytest_test.py`、`assets/templates/junit_test.java`
```

---

## 六、目录结构规范

### 标准 skill 目录结构

```
skills/
  <skill-name>/
    SKILL.md                    # 必需，主文档
    references/                 # 可选，详细文档
      <topic>.md
    assets/                     # 可选，模板和示例
      templates/
        <template-file>
      examples/
        <example-file>
```

### 命名规范
- skill 目录名：kebab-case（如 `code-review`、`unit-test`）
- SKILL.md：固定名称，全大写
- references/ 中的文件：kebab-case（如 `security-checklist.md`）
- assets/ 中的文件：根据语言习惯（如 `jest.test.ts`、`test_example.py`）

---

## 七、质量检查清单

在提交 skill 前，检查以下事项：

### frontmatter 检查
- [ ] `name` 字段存在且唯一
- [ ] `name` 与目录名一致
- [ ] `description` 简洁明了（< 80 字）
- [ ] `description` 包含触发场景与输出
- [ ] `metadata.version` 符合 semver 格式

### 正文结构检查
- [ ] 包含所有必需小节（适用场景、必须材料、执行步骤、产物与格式、质量门槛、验证方式、不覆盖范围、引用资料）
- [ ] 使用中文小节标题
- [ ] 引用全局上下文的通用规范
- [ ] 验证方式引用全局通用流程

### 内容质量检查
- [ ] 执行步骤清晰可操作
- [ ] 产物格式有明确示例
- [ ] 检查项可验证
- [ ] 不覆盖范围明确
- [ ] 无与全局上下文冲突的规则

### 文件组织检查
- [ ] references/ 中的文件确实被 SKILL.md 引用
- [ ] assets/ 中的模板确实被 SKILL.md 引用
- [ ] 无冗余文件
- [ ] 目录名符合命名规范

---

## 八、常见问题

### Q1: 何时创建新 skill vs 扩展现有 skill？
**创建新 skill**：
- 任务类型不同（如 code-review vs unit-test）
- 流程差异显著
- 产物格式完全不同

**扩展现有 skill**：
- 只是增加新的场景分支
- 产物格式相似
- 流程大体相同

### Q2: 如何避免 skill 间重复？
- 通用规范放全局上下文
- skill 特定内容才放 SKILL.md
- 多个 skill 共享的详细文档考虑放全局或创建独立文档

### Q3: references/ 文件过多怎么办？
- 按主题分组（如 `references/security/`、`references/performance/`）
- 但 SKILL.md 必须在根目录
- 引用时使用相对路径（如 `references/security/owasp.md`）

### Q4: 如何处理多语言支持？
- references/ 中按语言分文件（如 `js-jest.md`、`python-pytest.md`）
- SKILL.md 中说明适配方式
- 示例和模板按语言分组

---

## 九、贡献流程

1. **规划**：明确 skill 的范围与边界
2. **编写**：按照本指南创建 SKILL.md 和相关文档
3. **自检**：使用质量检查清单验证
4. **测试**：在实际项目中验证 skill 的可用性
5. **提交**：创建 PR 并说明 skill 的用途

---

## 十、参考资源

- 全局上下文：`GEMINI.md`
- 现有 skills 示例：`skills/unit-test/`、`skills/code-review/`
- Agent Skills 工具：`README.md`
