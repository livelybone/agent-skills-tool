# 锚点命名空间规范

`docs/models/<scenario>/<name>.md` 使用 HTML 注释锚点（`<!-- anchor: <Namespace>.<Name> -->`），供下游 skill 通过 `upstream-ref: docs/models/<scenario>/<name>.md#<Namespace>.<Name>` 方式机械引用。

**命名空间按 scenario 分类**（`upstream-ref` 以完整文件路径为作用域，同名命名空间可在不同文件中共存）。

## `domain/<name>.md` 可用

- `Aggregate.<Name>` — 本单元持有的聚合（Aggregates 前置章节声明）
- `Entity.<Name>` — 领域实体（业务实体的**唯一主权定义**）
- `Rel.<A>-<B>` — 实体关系
- `Derivation.<Entity>.<field>` — 业务派生关系
- `Invariant.<Entity>.<N>` — 模块内业务不变量
- `Invariant.<Entity>.cross.<N>` — 跨模块业务不变量（本模块为执行者）
- `StateMachine.<Entity>[.<Name>]` — 业务状态机
- `Process.<Name>` — 业务流程（若独立度高应考虑拆到 `process/`）

## `ui/<name>.md` 可用

- `Entity.<Name>` — UI 视图模型 / 展示投影（**不得与 `domain/` 同名实体重复**）
- `Rel.<A>-<B>` — 视图间或视图与页面的关系
- `Derivation.<Entity>.<field>` — 视觉领域派生
- `Invariant.<Entity>.<N>` — UI 约束
- `StateMachine.<Entity>[.<Name>]` — UI 状态机（如拖拽、模态框、多步表单）
- `Component.<Name>` — 本单元内部共享的 UI 组件（跨模块共享的升级到 `components/`）

## `components/<family>.md` 可用

- `Component.<Name>` — 组件定义（通用组件或业务共用组件的**唯一主权定义**）
- `Derivation.<Component>.<field>` — 组件视觉派生
- `StateMachine.<Component>[.<Name>]` — 组件状态机
- `Invariant.<Component>.<N>` — 组件约束
- `Rel.<A>-<B>` — 组件间关系（如 Modal 嵌套 Form）

## `process/<name>.md` 可用

- `Process.<Name>` — 流程主体（核心产出）
- `Rel.<A>-<B>` — 流程与其他单元（domain/process）之间的关系，承载契约线索
- `StateMachine.<Entity>[.<Name>]` — 仅当状态机是流程私有的（与业务实体的生命周期解耦）
- `Invariant.<Subject>.<N>` — 流程内部约束（如并发、幂等、超时）；`<Subject>` 可以是 `Process` 或被引用的实体名
- `Invariant.<Subject>.cross.<N>` — 跨模块约束（本单元为执行者）；`<Subject>` 同上

> 业务实体（含聚合内部实体，如 ApprovalStep、OrderItem）归属于对应的 `domain/<name>.md`，不在 `process/` 定义。process 单元通过 `upstream-ref` 引用业务实体。

## `state-machine/<name>.md` 可用

- `StateMachine.<Entity>[.<Name>]` — 状态机主体
- `Invariant.<Entity>.<N>` — 状态机约束

## 例外写法（显式标记无内容）

- `Invariant.<Subject>.none` — 显式无不变量（需给出理由）。`<Subject>` 与上方各 scenario 段中 `Invariant.<...>` 的主体范围一致
- `Aggregate.none` — 本单元不持有聚合（适用于非 `domain/` 的单元）

---

本 skill 只保证**产出契约**；下游如何消费契约由调用方 skill 自行定义。
