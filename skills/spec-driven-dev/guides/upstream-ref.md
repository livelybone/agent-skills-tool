# upstream-ref 规范（唯一定义点）

本 guide 只补充 `SKILL.md` 中建模产物引用与机械校验使用的 upstream-ref 格式，不定义阶段顺序或 gate 推进规则。

> **本文件是 upstream-ref 语法、锚点命名、N/A 规则的唯一权威定义。** 所有 prompt、workflow、guide 文件引用本文件，不得各自重新定义。

## 语法

```
upstream-ref: <doc>#<anchor>[, <doc>#<anchor>]*
或
upstream-ref: N/A + <具体理由>
```

## `<doc>` 约束

建模文件的路径，必须以下述形式作结尾（最后两段路径段）：

```
<scenario>/<name>.md
```

其中：

- `<scenario>` 必须是 `modeling-first` v0.3+ 的 5 个固定 scenario 之一：`domain` / `ui` / `components` / `process` / `state-machine`
- `<name>` 是 kebab-case（小写字母+数字+连字符，首位字符必须是字母或数字）

允许写相对路径或完整路径（如 `docs/models/domain/orders.md` 与 `domain/orders.md` 都可——身份由最后两段决定）。`model.md` / `epic-model.md` 这类旧 basename 已**不再接受**：
- 用在 `--upstream` 参数上（注册 upstream 时路径不合规）→ `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh` 在加载阶段 `exit 1`（usage error）
- 用在产物的 `upstream-ref` 字段或矩阵行上 → 被 Check 1 以 `exit 2` 拒绝（fake upstream reference）

> `modeling-first` 的产物放置规则见 `skills/modeling-first/SKILL.md`、`skills/modeling-first/references/placement.md`——5 个 scenario 的语义及选择依据是那里的权威定义，本文件跟随其约定。

## `<anchor>` 约束

必须以 **`<!-- anchor: <Namespace>.<Name> -->` HTML 注释**形式在建模文件中显式声明。机械校验只认这种形式——heading / bold / 纯节标题**不被接受**。

### 锚点命名空间

命名空间、scenario 适用范围和例外写法以 `modeling-first/references/anchors.md` 为唯一真理源。本文件只规定 `spec-driven-dev` 如何引用和校验这些锚点。

**机械校验规则**（`$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-upstream-coverage.sh` 与 `$SPEC_DRIVEN_DEV_SKILL_DIR/scripts/check-plan-structure.sh` 共享）：

1. **形状**：锚点必须匹配 `^[A-Z][A-Za-z0-9]*\.[A-Za-z0-9._-]+`——即大驼峰前缀 + `.` + 名字
2. **存在性**：`<doc>#<anchor>` 引用的锚点必须在对应建模文件中以 `<!-- anchor: X -->` 注释形式真实声明（Check 1 硬卡点）
3. **路径有效性**：`<doc>` 的最后两段必须匹配 `<scenario>/<name>.md`；其他路径一律视为无效引用

脚本**不闭枚举命名空间**：`modeling-first` 新增命名空间无需同步改脚本。命名空间**合法性**（是否属于当前约定的类别、是否适配对应 scenario）由 Modeling Review 兜底。

锚点形状正则（脚本只校验到这一层）：`[A-Z][A-Za-z0-9]*\.[A-Za-z0-9._-]+`

## 多条引用

一个产出可对应多条锚点，用逗号分隔：

```
upstream-ref: domain/order.md#Invariant.Order.3, domain/order.md#Derivation.Order.total
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
| Plan | `持有聚合` 指向 `domain/<name>.md#Aggregate.<Name>`；`模块依赖` / `产出契约` 指向**引用方单元**的 `Rel.<A>-<B>` 锚点（通常是 `domain/<name>.md`，也可以是 `process/<name>.md`——以 `modeling-first/references/cross-module.md` 权威规则为准） |
| Spec | 每条 Rule / State / State Transition 末尾行内标注 `（upstream-ref: <doc>#<anchor>）` |
| Scenario | 每个场景末尾 `↑ upstream-ref: ...`；具体场景格式由测试阶段 worker 定义 |
| Test | 顶部注释 `@upstream ...` 或测试名前缀；具体测试文件约定由测试阶段 worker 定义 |
| Impl | 关键位置注释 `// covers <upstream-ref>`；详细追溯由 Upstream Coverage Matrix 承载 |
| Coverage Matrix | 每条 upstream 条目占一行（格式见 `guides/upstream-coverage.md`）|

## 越界禁令

场景/Spec/Test 不允许引入建模文件中未声明的行为。若发现需要新的业务规则 → 先回修建模，再写下游产物。
