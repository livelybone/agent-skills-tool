# 提示模板 — 场景生成

读取 markdown 规范和**建模文件**，生成人类可读的测试场景。

## 前置引用

- **测试指南（测什么/不测什么/Overtest 过滤）**：见 `guides/testing.md`
- **场景格式和标记**：见 `guides/scenario-format.md`
- **upstream-ref 语法**：见 `guides/upstream-ref.md`
- **建模追溯与覆盖矩阵**：见 `guides/upstream-coverage.md`

## 必须输入（硬性前提）

- Spec（业务规范）
- **建模文件**（`docs/models/<scenario>/<name>.md`，由 `modeling-first` v0.3+ 产出）——**必须提供本模块涉及的全部建模单元**。
  - **豁免分支**：若 Spec frontmatter 含已通过独立审查的 `modeling_exemption` 字段（详见 SKILL.md 步骤 0"建模豁免"），允许无建模文件；此时场景的 `upstream-ref` 全部标 `N/A + <具体理由引用 modeling_exemption.rationale>`
  - **非豁免情况**：若建模文件缺失且 frontmatter 无合法 `modeling_exemption`，停止场景生成，向人工报告"建模未就绪，无法生成场景"，不得凭空生成

## 要求

- 输出自然语言场景
- 避免测试函数名
- 覆盖主流程
- 包含失败案例
- **从 Rules 和建模文件系统性推导边界案例**（空值、边界值、非法状态、并发等），不依赖 Spec 预先列出
- 如相关，包含契约风险
- 如相关，包含不变量
- **每个场景标记测试类型和 [CRITICAL]**（格式和标记规则见 `guides/scenario-format.md`）
- **每个场景必须带 `upstream-ref`**（语法见 `guides/upstream-ref.md`，场景内格式见 `guides/scenario-format.md`）
- **建模覆盖完整性**：建模文件中的**每条** Invariant 至少一个 `[PROPERTY]` 或断言场景；**每条** Derivation 至少一个 `[UNIT]` 场景验证等式；**每条** Relationship 至少一个场景验证基数/所有权/删除语义

## 过度测试过滤

生成场景后，按 `guides/testing.md` > Overtest 过滤清单逐条自查，删除属于 Overtest 类别的场景。**判断标准**：删掉这个场景后是否有实际业务风险未被覆盖？"否"则删除。

## 输出格式

严格遵循 `guides/scenario-format.md` 定义的格式。
