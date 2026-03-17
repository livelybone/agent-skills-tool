# CHANGELOG 更新规范

## 基本格式（Keep a Changelog）

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 新功能描述

### Changed
- 变更描述

### Deprecated
- 即将废弃的功能

### Removed
- 已移除的功能

### Fixed
- Bug 修复描述

### Security
- 安全相关的修复

## [1.0.0] - 2024-01-15

### Added
- Initial release
- Feature X
- Feature Y

[Unreleased]: https://github.com/user/repo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

## 变更类型

### Added（新增）
用于新功能。

**示例：**
```markdown
### Added
- User authentication with JWT
- Export to PDF functionality
- Dark mode support
- API rate limiting
```

### Changed（变更）
用于现有功能的变更。

**示例：**
```markdown
### Changed
- Improved error handling in API responses
- Updated UI for better mobile experience
- Optimized database query performance
- Changed default timeout from 30s to 60s
```

### Deprecated（即将废弃）
用于即将在未来版本中移除的功能。

**示例：**
```markdown
### Deprecated
- `/api/v1/users` endpoint (use `/api/v2/users` instead)
- `oldAuthMethod()` function (use `newAuthMethod()`)
```

### Removed（已移除）
用于已经移除的功能。

**示例：**
```markdown
### Removed
- Support for Internet Explorer 11
- Legacy authentication API (`/api/v1/auth`)
- Deprecated configuration options
```

### Fixed（修复）
用于 bug 修复。

**示例：**
```markdown
### Fixed
- Fixed memory leak in image processing
- Resolved timeout issue with large file uploads
- Fixed incorrect calculation in tax module
- Resolved security vulnerability in user input validation
```

### Security（安全）
用于安全相关的修复和改进。

**示例：**
```markdown
### Security
- Patched XSS vulnerability in comment system
- Updated dependencies to resolve security vulnerabilities
- Improved password encryption algorithm
```

## 版本号规则（Semantic Versioning）

格式：`MAJOR.MINOR.PATCH`

- **MAJOR**：不兼容的 API 变更
- **MINOR**：向后兼容的功能新增
- **PATCH**：向后兼容的 bug 修复

**示例：**
- `1.0.0` → `1.0.1`：Bug 修复
- `1.0.1` → `1.1.0`：新功能
- `1.1.0` → `2.0.0`：Breaking Changes

## 更新流程

### 1. 每次提交时更新 Unreleased 部分
```markdown
## [Unreleased]

### Added
- User profile page

### Fixed
- Login timeout issue
```

### 2. 发布版本时，将 Unreleased 移到新版本
```markdown
## [Unreleased]

## [1.1.0] - 2024-01-20

### Added
- User profile page

### Fixed
- Login timeout issue

## [1.0.0] - 2024-01-15
...
```

### 3. 更新底部的链接
```markdown
[Unreleased]: https://github.com/user/repo/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/user/repo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

## 完整示例

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Real-time notification system
- User preference settings

### Changed
- Improved search performance

## [2.0.0] - 2024-02-01

### Added
- New API v2 with improved authentication
- Support for multiple payment methods
- Batch operations for bulk data processing

### Changed
- **BREAKING**: Authentication now requires Bearer token instead of API key
- Redesigned user interface
- Updated database schema for better performance

### Deprecated
- API v1 endpoints (will be removed in v3.0.0)

### Removed
- Support for Node.js 12 and 14
- Legacy webhook system

### Fixed
- Memory leak in background job processor
- Race condition in concurrent uploads
- Incorrect timezone handling

### Security
- Patched SQL injection vulnerability
- Updated all dependencies to latest secure versions

## [1.5.0] - 2024-01-20

### Added
- User profile customization
- Export data to CSV

### Fixed
- Login timeout on slow networks
- File upload progress indicator accuracy

## [1.0.0] - 2024-01-15

### Added
- Initial stable release
- User authentication
- Basic CRUD operations
- REST API documentation

[Unreleased]: https://github.com/user/repo/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/user/repo/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/user/repo/compare/v1.0.0...v1.5.0
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

## 编写原则

### Do（推荐）
- ✓ 从用户角度描述变更（用户能看到/感受到的变更）
- ✓ 使用简洁明了的语言
- ✓ Breaking Changes 用 `**BREAKING**` 标注
- ✓ 安全相关的修复单独列在 Security 部分
- ✓ 按时间倒序排列（最新的在上面）
- ✓ 包含版本发布日期

### Don't（避免）
- ✗ 列出每个 commit 的详细内容
- ✗ 记录内部重构（除非影响用户）
- ✗ 使用技术术语（除非必要）
- ✗ 遗漏 Breaking Changes
- ✗ 版本号不遵循语义化版本规范

## 特殊场景

### 项目初始化时创建 CHANGELOG
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Project initialization
- Basic project structure
```

### Breaking Changes
```markdown
## [2.0.0] - 2024-02-01

### Changed
- **BREAKING**: Minimum Node.js version is now 18
- **BREAKING**: Authentication API redesigned (see migration guide)
- **BREAKING**: Configuration file format changed from JSON to YAML

### Migration Guide
#### Authentication API
Old:
  POST /api/login
  Body: { "apiKey": "..." }

New:
  POST /api/v2/auth/login
  Header: Authorization: Bearer YOUR_TOKEN
```

### Alpha/Beta 版本
```markdown
## [1.0.0-beta.2] - 2024-01-10

### Added
- New experimental feature X

### Known Issues
- Feature X may cause performance issues with large datasets
- UI needs polish

## [1.0.0-beta.1] - 2024-01-05
...
```

### Hotfix
```markdown
## [1.2.1] - 2024-01-25

### Security
- **URGENT**: Patched critical XSS vulnerability

### Fixed
- Emergency fix for production crash
```

## 自动化建议

### 从 Git 历史生成
可以使用工具从 git commit 历史自动生成 CHANGELOG：
- [conventional-changelog](https://github.com/conventional-changelog/conventional-changelog)
- [auto-changelog](https://github.com/CookPete/auto-changelog)

**前提：** commit message 遵循 Conventional Commits 规范

### CI/CD 集成
- 在 CI 中检查 CHANGELOG 是否已更新
- 发布时自动将 Unreleased 移到新版本
- 自动生成 GitHub Release Notes
