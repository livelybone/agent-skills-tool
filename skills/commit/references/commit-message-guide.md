# Commit Message 规范

## 基本格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 各部分说明

- **type**：必需，变更类型
- **scope**：可选，影响范围
- **subject**：必需，简短描述（50 字符以内）
- **body**：可选，详细描述
- **footer**：可选，关联 issue、Breaking Changes 等

## Type 类型

| Type | 说明 | 示例 |
|------|------|------|
| feat | 新功能 | feat(auth): add JWT authentication |
| fix | 修复 bug | fix(login): resolve token expiration issue |
| docs | 文档变更 | docs(readme): update installation guide |
| style | 代码格式（不影响代码运行） | style(format): apply prettier formatting |
| refactor | 重构（既不是新功能也不是修复 bug） | refactor(api): simplify error handling |
| perf | 性能优化 | perf(query): optimize database query |
| test | 测试相关 | test(auth): add unit tests for login |
| build | 构建系统或外部依赖变更 | build(deps): upgrade to React 18 |
| ci | CI 配置变更 | ci(github): add automated testing |
| chore | 其他不修改 src 或 test 的变更 | chore(config): update eslint rules |
| revert | 回退之前的 commit | revert: revert "feat: add feature X" |

## Scope 范围

**原则：** 用简短的词描述变更影响的范围

**示例：**
- 模块名：`auth`、`user`、`payment`
- 组件名：`header`、`sidebar`、`button`
- 功能名：`login`、`upload`、`export`

## Subject 主题

**规则：**
- 使用祈使句，现在时（"add" 而非 "added" 或 "adds"）
- 首字母小写
- 结尾不加句号
- 50 字符以内

**好的示例：**
```
add user authentication
fix memory leak in image processing
update API documentation
```

**不好的示例：**
```
Added user authentication.  // 使用了过去时，有句号
fixed bug  // 不够具体
Updated the API documentation for the new version  // 太长
```

## Body 正文

**何时需要：**
- 变更原因需要解释
- 实现方式需要说明
- 有多个相关的变更

**格式：**
- 与 subject 之间空一行
- 每行不超过 72 字符
- 可以分多段
- 说明"是什么"和"为什么"，而不只是"怎么做"

**示例：**
```
feat(cache): implement Redis caching layer

Added Redis caching to improve API response time.
Cache is used for:
- User profile data (TTL: 1 hour)
- Product catalog (TTL: 5 minutes)
- Search results (TTL: 10 minutes)

This reduces database load by ~60% during peak hours.
```

## Footer 页脚

**用途：**
- 关联 issue：`Closes #123`、`Fixes #456`
- Breaking Changes：`BREAKING CHANGE: ...`
- Co-authors：`Co-Authored-By: Name <email>`

**示例：**
```
feat(api): redesign authentication API

BREAKING CHANGE: Authentication API now requires API version in header.
Old: POST /login
New: POST /v2/login with header "X-API-Version: 2"

Closes #234
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

## 完整示例

### 示例 1：新功能
```
feat(payment): add Stripe payment integration

Implemented Stripe payment gateway with support for:
- Credit card payments
- Subscription management
- Webhook handling for payment events

Includes error handling for failed payments and
automatic retry mechanism.

Closes #456
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### 示例 2：Bug 修复
```
fix(upload): resolve file upload timeout issue

Fixed timeout error when uploading large files (>10MB).

Changes:
- Increased upload timeout from 30s to 5min
- Added progress indicator
- Implemented chunked upload for files >50MB

Fixes #789
```

### 示例 3：重构
```
refactor(database): migrate from SQLite to PostgreSQL

Migrated database from SQLite to PostgreSQL for better
performance and scalability.

Migration includes:
- Schema conversion scripts
- Data migration tool
- Updated ORM configuration

All existing tests pass after migration.

Closes #123
```

### 示例 4：Breaking Change
```
feat(api): update API authentication

BREAKING CHANGE: API now requires Bearer token instead of API key.

Old: Authorization: ApiKey YOUR_KEY
New: Authorization: Bearer YOUR_TOKEN

Migration guide:
1. Generate new token at /settings/tokens
2. Update API client to use Bearer auth
3. Old API keys will be deprecated on 2024-06-01

Closes #345
```

## 最佳实践

### Do（推荐）
- ✓ 一个 commit 只做一件事
- ✓ subject 清晰描述变更内容
- ✓ 重要变更在 body 中详细说明
- ✓ 关联相关的 issue
- ✓ Breaking Changes 明确标注

### Don't（避免）
- ✗ 一个 commit 包含多个不相关的变更
- ✗ 模糊的 subject（如 "fix bug"、"update code"）
- ✗ 使用过去时（"added"、"fixed"）
- ✗ subject 超过 50 字符
- ✗ 不说明 Breaking Changes

## 特殊场景

### WIP（Work in Progress）
```
wip: implement user profile feature

Temporary commit, not ready for review.
```

### Hotfix
```
hotfix(security): patch XSS vulnerability

Emergency fix for reported XSS vulnerability in user input.
Detailed security audit and tests will follow in next commit.

Fixes #URGENT-123
```

### Revert
```
revert: revert "feat: add experimental feature X"

This reverts commit a1b2c3d4.

Reason: Feature X causes performance regression in production.
Will re-implement with proper optimization in future PR.
```

## AI 协助时的特殊标注

**当 AI 协助编写代码时，建议在 footer 中添加：**
```
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

或
```
Co-Authored-By: GitHub Copilot <noreply@github.com>
```
