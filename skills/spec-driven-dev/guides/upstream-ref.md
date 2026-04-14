# upstream-ref 规范（唯一定义点）

> **本文件是 upstream-ref 语法、锚点命名、N/A 规则的唯一权威定义。** 所有 prompt、workflow、guide 文件引用本文件，不得各自重新定义。

## 语法

```
upstream-ref: <doc>#<anchor>[, <doc>#<anchor>]*
或
upstream-ref: N/A + <具体理由>
```

## `<doc>` 约束

建模文件的相对路径，**只接受** `model.md` / `epic-model.md` 两种 basename（可带路径前缀如 `../epic-model.md`）。其他文件名一律视为无效引用，被 `scripts/check-upstream-coverage.sh` 直接拒绝（exit 2）。

## `<anchor>` 约束

必须以 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释**形式在建模文件中显式声明。机械校验只认这种形式——heading / bold / 纯节标题**不被接受**。

### 锚点命名空间（固定 6 类）

| 命名空间 | 格式 | 示例 |
|---------|------|------|
| `Entity` | `Entity.<Name>` | `Entity.Order` |
| `Rel` | `Rel.<A>-<B>`（持有方在前）| `Rel.Order-OrderItem` |
| `Invariant` | `Invariant.<Entity>.<N>`（N 从 1 起）| `Invariant.Order.3` |
| `Derivation` | `Derivation.<Entity>.<field>` | `Derivation.Order.total` |
| `Aggregate` | `Aggregate.<Name>` | `Aggregate.Payment` |
| `SharedInvariant` | `SharedInvariant.<N>` | `SharedInvariant.1` |

锚点命名规范正则：`(Entity|Rel|Invariant|Derivation|Aggregate|SharedInvariant)\.[A-Za-z0-9._-]+`

## 多条引用

一个产出可对应多条锚点，用逗号分隔：

```
upstream-ref: model.md#Invariant.Order.3, model.md#Derivation.Order.total
```

## N/A 规则

仅当确实不对应任何建模条目时可标 `N/A`（如纯基础设施测试、兼容性回归测试），**必须附具体理由**。审查时会质问理由合理性。

不接受的理由：
- "这个场景太基础了"
- "这条不变量太难测"
- "这个派生关系很显然"

## 各阶段的落位方式

| 阶段 | upstream-ref 位置 |
|------|-----------------|
| Plan | `持有聚合` / `模块依赖` / `产出契约` 字段，以 `epic-model.md#<anchor>` 形式 |
| Spec | 每条 Rule / State / State Transition 末尾行内标注 `（upstream-ref: <doc>#<anchor>）` |
| Scenario | 每个场景末尾 `↑ upstream-ref: ...`（格式见 `guides/scenario-format.md`）|
| Test | 顶部注释 `@upstream ...` 或测试名前缀（格式见 `prompts/test-implementation.md`）|
| Impl | 关键位置注释 `// covers <upstream-ref>`；详细追溯由 Upstream Coverage Matrix 承载 |
| Coverage Matrix | 每条 upstream 条目占一行（格式见 `guides/upstream-coverage.md`）|

## 越界禁令

场景/Spec/Test 不允许引入建模文件中未声明的行为。若发现需要新的业务规则 → 先回修建模，再写下游产物。
