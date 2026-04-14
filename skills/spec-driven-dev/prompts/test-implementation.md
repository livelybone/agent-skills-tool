# 提示模板 — 测试实现

基于批准的场景实现自动化测试。

## 前置引用

- **测试指南（测什么/不测什么/Stub 规则/Red Run/禁止事项）**：见 `guides/testing.md`
- **测试文件位置和命名**：见 `guides/repo-structure.md`
- **测试类型优先级**：见 `guides/scenario-format.md` > 测试类型标记
- **upstream-ref 语法**：见 `guides/upstream-ref.md`

## 要求

- **按场景的测试类型标记（CONTRACT / INTEGRATION / PROPERTY / UNIT）决定测试类型**，不自行判断
- **每个测试必须标注追溯字段**（语法见 `guides/upstream-ref.md`）：
  - `@scenario <scenario-id 或描述>` — 对应哪个场景
  - `@upstream <upstream-ref>` — 从场景继承的上游契约引用
- 追溯字段放在测试用例顶部注释或测试名前缀（语言/框架约定的任一种）
- 优先行为级别测试
- 优先工作流的集成测试
- 当 API 模式稳定性重要时添加契约测试
- 当存在不变规则时添加属性测试
- 不要修改场景含义
- 不要削弱现有测试

### 追溯示例

```ts
// @scenario S-3 [CRITICAL][INTEGRATION] 用户取消已发货订单 → 取消失败
// @upstream model.md#Invariant.Order.5
it('rejects cancel when status is shipped', async () => {
  // ...
});
```

或使用测试名前缀：

```ts
it('[S-3 / model.md#Invariant.Order.5] rejects cancel when status is shipped', async () => {
  // ...
});
```

追溯字段的作用：
- **审查**：跨 agent 审查时检查 scenario → test → upstream 链条完整
- **CI 校验**：机械检查 upstream-ref 是否存在（见 `guides/upstream-coverage.md`）
- **覆盖矩阵**：Impl 阶段生成 Upstream Coverage Matrix 时需要读取

## 测试原则

见 `guides/testing.md` 中的"行为契约 vs 实现路径"和"Overtest 过滤清单"。核心要求：

- 测试行为而非内部实现
- 避免与私有辅助函数绑定的脆弱测试
- 确保测试能验证场景中描述的行为

## 前置步骤：建立 Implementation Stub

详细规则见 `guides/testing.md` > Implementation Stub 规则。简要：

- 被测模块文件不存在时，先创建 Stub（正确路径 + 正确签名 + `throw new Error('not implemented')` 函数体）
- Stub 仅用于 import 可解析，不计入测试完成度

## 职责边界

**本阶段完成：Implementation Stub + 全部场景的行为测试。**

- Stub 不得写任何实际逻辑
- 禁止为了"让测试能跑通"而实现功能代码
- 测试文件写完后，功能代码尚不存在是正常的——测试应该是红色的

## 测试完成度 / 禁止事项

见 `guides/testing.md` > 测试完成度定义 + 禁止事项。
