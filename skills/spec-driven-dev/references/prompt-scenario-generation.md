# 提示模板 — 场景生成

读取 markdown 规范并生成人类可读的测试场景。

## 要求

- 输出自然语言场景
- 避免测试函数名
- 覆盖主流程
- 包含失败案例
- **从 Rules 系统性推导边界案例**（空值、边界值、非法状态、并发等），不依赖 Spec 预先列出
- 如相关，包含契约风险
- 如相关，包含不变量
- **每个场景标记测试类型**（`[CONTRACT]` / `[INTEGRATION]` / `[PROPERTY]` / `[UNIT]`）
- **关键场景额外标记 `[CRITICAL]`**

## 场景格式

```
[TEST_TYPE] 用户执行操作
→ 系统行为

[CRITICAL][TEST_TYPE] 用户执行高风险操作
→ 系统行为
```

## 测试类型标记

每个场景必须标注测试类型，供 Test Implementation 阶段直接使用：

| 标记 | 适用场景 |
|------|---------|
| `[CONTRACT]` | API 响应结构、错误码、对外承诺 |
| `[INTEGRATION]` | 端到端业务流程 |
| `[PROPERTY]` | 不变量（任意输入下成立的规则）|
| `[UNIT]` | 单一函数/规则的孤立验证 |

优先级：**CONTRACT > INTEGRATION > PROPERTY > UNIT**

## 关键测试标记

高风险场景额外加 `[CRITICAL]`，人工审查时优先关注：

```
[CRITICAL][CONTRACT] 用户尝试使用过期折扣码
→ 请求失败，返回 EXPIRED_CODE，不扣减库存

[CRITICAL][INTEGRATION] 用户支付订单
→ 订单状态变为 PAID，库存扣减

[PROPERTY] 折扣金额不超过订单总额
→ 任意输入下此不变量成立

[INTEGRATION] 用户创建订单时不提供折扣码
→ 订单正常创建
```

`[CRITICAL]` 判断标准：

1. **Contract（契约）**：涉及 API 响应结构、错误码、对外承诺
2. **Money（金钱）**：涉及支付、退款、折扣计算
3. **Permission（权限）**：涉及访问控制、数据安全
4. **State Transition（状态转换）**：涉及关键业务状态变化
5. **Data Integrity（数据完整性）**：涉及数据一致性、关联完整性
