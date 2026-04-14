# 场景格式

使用人类可读的行为描述，每个场景必须标注：**测试类型** + **upstream-ref**。

## 首选格式

```
[TEST_TYPE] 用户执行操作
→ 系统行为
↑ upstream-ref: <上游契约锚点>

[CRITICAL][TEST_TYPE] 用户执行高风险操作
→ 系统行为
↑ upstream-ref: <上游契约锚点>
```

示例（upstream 为 model.md）：

```
[INTEGRATION] 用户创建未付款订单
→ 订单状态变为 CREATED
↑ upstream-ref: model.md#Invariant.Order.2

[INTEGRATION] 用户支付现有订单
→ 订单状态变为 PAID
↑ upstream-ref: model.md#Invariant.Order.4

[CRITICAL][INTEGRATION] 用户取消已发货订单
→ 取消失败
↑ upstream-ref: model.md#Invariant.Order.5
```

不要输出测试函数名（如 `test_cancel_shipped_order_should_fail`）。

## upstream-ref 规则

每个场景**必须**带 `upstream-ref`。完整语法、锚点命名空间、N/A 规则见 `upstream-ref.md`（本目录下的唯一定义点）。

场景内的格式：末尾用 `↑ upstream-ref: <doc>#<anchor>` 标注（见上方示例）。一个场景可对应多条锚点，用逗号分隔。

## 测试类型标记

| 标记 | 适用场景 |
|------|---------|
| `[CONTRACT]` | API 响应结构、错误码、对外承诺 |
| `[INTEGRATION]` | 端到端业务流程 |
| `[PROPERTY]` | 不变量（任意输入下成立的规则）|
| `[UNIT]` | 单一函数/规则的孤立验证 |

优先级：**CONTRACT > INTEGRATION > PROPERTY > UNIT**

## [CRITICAL] 标记

高风险场景额外加 `[CRITICAL]`。判断标准：

1. **Contract（契约）**：涉及 API 响应结构、错误码、对外承诺
2. **Money（金钱）**：涉及支付、退款、折扣计算
3. **Permission（权限）**：涉及访问控制、数据安全
4. **State Transition（状态转换）**：涉及关键业务状态变化
5. **Data Integrity（数据完整性）**：涉及数据一致性、关联完整性

人工审查时，**优先关注标记为 [CRITICAL] 的场景**。
