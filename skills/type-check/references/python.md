
# Python 类型安全规范

## 核心配置（pyproject.toml）

```toml
[tool.mypy]
python_version = "3.10"
disallow_any_expr = true
disallow_any_explicit = true
disallow_untyped_defs = true
```

## 执行脚本（示例，按项目现有任务入口承载）

```bash
# Makefile、nox/tox 或其他任务入口中必须包含
type-check:
  python -m mypy .

build:
  python -m mypy . && python -m build
```

## 规则要求

- 禁止使用未注解函数与变量
- 函数参数、返回值与类属性必须显式类型
- 第三方依赖必须包含类型定义
- 复杂数据结构必须显式类型别名或 Protocol

## 建议增强项（按项目接受度选择）

- `warn_unused_ignores = true`
- `no_implicit_optional = true`
- `check_untyped_defs = true`

## 执行要求

- 构建前必须执行 `type-check`
- CI 必须包含类型检查步骤

## 检查清单

```
□ pyproject.toml 包含 mypy 配置
□ 存在明确的 type-check 命令
□ 构建与 CI 含类型检查前置
```
