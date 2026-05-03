# Models Index

> 跨 scenario 索引，辅助导航。**非 single source of truth**——项目全局视图仍通过扫描 `docs/models/` 目录下所有建模文件聚合得到。本文件不持有锚点，不能被下游 `upstream-ref` 引用。

## process/

- [skill-fusion-overview](process/skill-fusion-overview.md) — Epic mattpocock-fusion 4 个 skill（debugging / adr-recorder / code-review / modeling-first）的边界与契约
- [spec-driven-dev](process/spec-driven-dev.md) — spec-driven-dev 顶层编排器流程模型

## domain/

- [skill-delivery-architecture](domain/skill-delivery-architecture.md) — skill 交付架构的领域建模
- [spec-driven-dev](domain/spec-driven-dev.md) — spec-driven-dev 内部领域实体

## ui/

(本仓库当前无 ui/ 单元)

## components/

(本仓库当前无 components/ 单元)

## state-machine/

(本仓库当前无 state-machine/ 单元)

---

**维护说明**：本文件目前由 modeling-first skill 的人工维护起步，自动化生成机制是 v0.4 候选。新增 model 文件时手工添加索引行；model 移除时手工删除。本文件**不持有 HTML 注释形式的锚点标记**，不可被下游 `upstream-ref` 引用。
