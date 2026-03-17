---
name: type-check
description: 配置类型检查/执行类型检查/修复类型错误；输出类型检查结果
metadata:
  version: 1.0.0
---

# 类型检查

## 适用场景
- 新项目配置类型检查系统
- 执行现有项目的类型检查
- 修复类型错误
- 提升项目类型安全等级

## 必须材料
- 目标语言与工具链（TypeScript/JavaScript、Python 等）
- 现有配置与脚本（如 tsconfig.json、mypy.ini、CI 配置）
- 当前类型错误列表（如有）

## 执行步骤
1. 明确语言与类型检查工具链（如 TypeScript、mypy、pyright）
2. 检查现有配置与执行脚本是否缺失
3. 按技术栈补齐配置并说明关键选项
4. 运行类型检查并记录错误
5. 逐个修复类型错误（优先 error，其次 warning）
6. 确保构建或 CI 中强制执行类型检查

## 产物与格式
- **类型检查入口命令**：如 `npm run typecheck`、`mypy .`
- **配置文件**：如 `tsconfig.json`、`mypy.ini`（如需创建或修改）
- **配置变更说明**：说明关键选项（如 `strict`、`noImplicitAny`）
- **错误修复摘要**：修复前后的错误数量对比
- **风险提示**：类型修复可能引入的运行时风险

## 质量门槛

> 遵循全局上下文中的"检查清单执行规则"

### 核心要求
- **类型检查已集成到 CI**：确保每次提交都运行类型检查
- **避免隐式 any**：配置 `noImplicitAny`（TypeScript）或 strict 模式
- **避免不安全类型断言**：减少 `as any`、`@ts-ignore` 的使用
- **严格度调整需说明理由**：降低严格度必须记录原因与风险

### 检查清单（核心）

**配置检查**：
- [ ] 类型检查工具已安装（如 TypeScript、mypy）
- [ ] 配置文件存在且合理（如 `tsconfig.json`、`mypy.ini`）
- [ ] 已启用合理的严格度（如 `strict: true`）
- [ ] CI 或构建脚本中包含类型检查步骤

**类型质量检查**：
- [ ] 无隐式 any（除非明确标注）
- [ ] 无未使用的 `@ts-ignore` 或 type 断言
- [ ] 公共 API 有明确的类型声明

详细检查清单见：
- `references/ts-js.md`（TypeScript/JavaScript 特定）
- `references/python.md`（Python 特定）

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定的验证
1. **发现类型检查命令**
   - 检查 `package.json` scripts（TypeScript/JavaScript）
   - 检查 `pyproject.toml` 或项目根目录（Python）
   - 常见命令：`npm run typecheck`、`tsc --noEmit`、`mypy .`、`pyright`

2. **运行类型检查**
   - 执行发现的命令
   - 记录错误数量与详细信息
   - 退出码必须为 0（无 error）

3. **验证 CI 集成**
   - 检查 CI 配置文件（如 `.github/workflows/*.yml`、`.gitlab-ci.yml`）
   - 确认类型检查步骤存在且会阻止构建

## 不覆盖范围
- 不替代单元测试或运行时验证
- 不负责重构代码架构（仅修复类型错误）
- 不负责性能优化

## 覆盖声明

**降低严格度例外**：
- 覆盖项：全局上下文#检查清单执行规则 - 类型检查强制执行
- 理由：遗留项目逐步迁移，一次性修复成本过高
- 替代验证：记录豁免文件列表，制定逐步收敛计划

## 引用资料
- `references/ts-js.md`（TypeScript/JavaScript 类型检查详细说明）
- `references/python.md`（Python 类型检查详细说明）
