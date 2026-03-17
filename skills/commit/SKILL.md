---
name: commit
description: 提交代码/git commit/更新 CHANGELOG；输出规范 commit message
metadata:
  version: 1.0.0
---

# 代码提交专项

## 适用场景
- 完成代码修改后的 git commit
- 需要生成规范 commit message
- 需要同步更新 CHANGELOG.md
- 提交前的质量检查

## 必须材料
- staged 文件列表与 diff
- 变更说明与关联 issue/任务号
- 是否需要更新 CHANGELOG.md
- 项目已有的检查命令（lint/test/类型检查）

## 执行步骤
1. 声明已加载 commit SKILL 并遵循其规则
2. 读取并执行提交前检查清单
3. 若检查失败，按对应规范排查修复
4. 生成符合规范的 commit message
5. 确认 CHANGELOG.md 更新（如需）
6. 执行 git commit

## 产物与格式

**规范的 commit message**：

```
<type>(<scope>): <short summary>

<body>（可选）

<footer>（可选）
```

**示例**：
```
feat(auth): add user login validation

- Implement email format validation
- Add password strength check
- Handle login error messages

Refs: #123
```

**type 类型**：
- `feat`: 新功能
- `fix`: 修复 bug
- `refactor`: 重构（不改变功能）
- `perf`: 性能优化
- `docs`: 文档更新
- `style`: 代码格式（不影响逻辑）
- `test`: 测试相关
- `chore`: 构建/工具配置

详细 commit message 规范见 `references/commit-message-guide.md`

**CHANGELOG.md 格式**：

详见 `references/changelog-guide.md`

## 质量门槛

> 遵循全局上下文中的"检查清单执行规则"

### 提交前强制检查清单（不可跳过）

**安全检查**：
- [ ] 无硬编码密码/token
- [ ] 无敏感文件路径
- [ ] .gitignore 已配置

**质量检查**：
- [ ] 运行 lint 命令（如 `npm run lint`、`eslint .`）
- [ ] 运行测试命令（如 `npm test`、`pytest`）
- [ ] 运行类型检查（如 `npm run typecheck`、`mypy`）

**提交内容检查**：
- [ ] 无临时文件、调试代码
- [ ] 无无关文件变更
- [ ] commit message 符合规范

详细检查清单见 `references/pre-commit-checklist.md`

## 验证方式

> 遵循全局上下文中的"验证方式通用流程"

### 本 skill 特定的验证
1. **发现并运行检查命令**
   - 检查项目配置文件，发现 lint/test/typecheck 命令
   - 按顺序运行并记录结果

2. **验证 commit message 格式**
   - 检查是否符合 `<type>(<scope>): <summary>` 格式
   - 检查 summary 长度（建议 ≤ 72 字符）

3. **验证 CHANGELOG 更新**（如适用）
   - 检查是否在正确的版本段落下添加
   - 检查格式是否符合规范

## 不覆盖范围
- 临时性 WIP commit（用户明确要求）
- 紧急提交（可允许，但需明确跳过的检查项与理由）
- git push 操作（仅负责 commit）
- 版本号管理与发布

## 覆盖声明

**紧急提交例外**：
- 覆盖项：全局上下文#检查清单执行规则 - 强制检查
- 理由：生产环境紧急修复，需立即提交
- 替代验证：提交后补充测试，创建跟进 issue

## 引用资料
- `references/pre-commit-checklist.md`（提交前检查清单）
- `references/commit-message-guide.md`（commit message 详细规范）
- `references/changelog-guide.md`（CHANGELOG 格式说明）
