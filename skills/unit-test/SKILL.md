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
