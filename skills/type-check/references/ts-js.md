
# TS/JS 类型安全规范

## 核心配置（tsconfig.json）

```json
{
  "compilerOptions": {
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwaysStrict": true
  }
}
```

## 强制脚本（package.json，包管理器命令按项目现有工具链）

```json
{
  "scripts": {
    "type-check": "tsc --noEmit",
    "lint": "eslint . && npm run type-check",
    "build": "npm run type-check && tsc"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

## 规则要求

- 尽量避免使用 `any`；遗留场景需标注原因并提供替代计划
- 函数参数、返回值与类属性必须显式类型
- 第三方依赖必须包含类型定义
- 复杂数据结构必须定义接口或类型别名

## 建议增强项（按项目接受度选择）

- 渐进式落地：先启用核心规则，后续逐步开启增强项
- 启用 `strict: true`
- 启用 `noUncheckedIndexedAccess`
- 启用 `exactOptionalPropertyTypes`
- 启用 `noImplicitOverride`

## 执行要求

- 构建前必须执行 `type-check`
- CI 必须包含类型检查步骤

## 检查清单

```
□ tsconfig.json 包含严格类型相关配置
□ 存在明确的 type-check 命令
□ 构建与 CI 含类型检查前置
```
