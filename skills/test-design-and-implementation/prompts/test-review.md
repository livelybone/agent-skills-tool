# 提示模板 — 跨 agent 审查测试代码

本文件仅作为 `multi-agent-loop` 的审查指令正文模板复用，不是可直接传给 `run_agent.sh` 的协议 prompt 文件。

使用独立 agent 审查当前测试代码，目标是检查 `Test Scenarios -> Executable Tests` 的翻译是否完整、准确，并找出追溯断链与过度测试问题。

## 输入

- 已批准的 `Test Scenarios`
- 当前实现的测试文件
- 若源 `TechnicalSpec` 的 `Upstream Models` 非 `N/A`：对应建模文件
- 若场景的 `upstream-ref` 统一走 `N/A + <reason>`：按 `../spec-driven-dev/guides/upstream-ref.md` 中定义的 N/A 规则审查

## 审查重点

### 1. 追溯链完整性

- 每个测试是否都带合法的 `@scenario`、`@spec-ref`、`@upstream` 三元组
- `@scenario` 是否指向真实存在的 `Scenario ID`
- `@spec-ref` 是否指向 `TechnicalSpec` 中真实存在的章节，并与对应场景声明的 `spec-ref` 一致
- `@upstream` 是否与对应场景的 `upstream-ref` 一致
- 若存在建模文件：`@upstream` 指向的锚点是否真实存在
- 若场景 `upstream-ref` 为 `N/A + <reason>`：`@upstream` 是否一致写成 `N/A + <reason>`，而不是伪造建模锚点

追溯断链、伪造上游引用、或 `N/A` 路径下越界写入建模锚点，都应按本任务严重度中的最高级别处理。

### 2. Scenario -> Test Coverage

- 每个场景是否至少有一个对应测试
- `[CRITICAL]` 场景是否被优先且完整地覆盖
- 测试是否覆盖了场景中明确写出的行为、错误语义、权限边界、状态变化和非功能断言
- 是否存在只覆盖了一半预期行为的测试
- 只验证导出存在、模块可 import、或文件存在的测试不算覆盖

对高风险场景的缺测或关键断言缺失，应按本任务严重度中的高等级处理。

### 3. Scope Violations

- 哪些测试在测场景之外的新行为
- 哪些测试把场景改写成了不同的边界或语义
- 哪些测试已经偏到实现路径，而不是场景描述的外部行为

### 4. Overtest Findings

- 哪些测试耦合私有 helper、内部调用顺序、内部状态存放位置或脆弱快照
- 哪些测试只是琐碎断言、重复路径或低价值冗余
- 对每个 overtest finding 说明：为什么它不在保护场景行为；删除后是否仍保留真实业务风险覆盖

### 5. Test Integrity

- 是否存在 `skip` / `todo` / `xit` / `xtest` 一类被跳过的占位测试
- 是否存在 `expect(true).toBe(true)`、只断言“不抛错”、或其他无法形成真实行为约束的弱断言
- 若使用 stub：stub 是否只保证公开契约与 import 可解析，而没有偷带业务逻辑、硬编码返回值、条件分支或真实副作用

### 6. Coverage Matrix View

- 审查时按 `Scenario ID -> tests` 的方式逐项核对
- 对每个场景给出：对应测试、断言摘要、缺口或越界问题
- 不需要重写测试，只输出 findings

## 严重度

级别类型固定为 `Critical / Major / Minor / Info` 四档（`multi-agent-loop` 协议不变量）。本任务下的具体含义如下——controller 合成 `agent-task.md` 时把这四行原样写入 `<严重度定义块>` 槽位：

- `[Critical]`：追溯断链、伪造上游引用、`[CRITICAL]` 场景未被测试覆盖，或测试断言错误翻译了场景语义
- `[Major]`：非 `[CRITICAL]` 场景的关键断言缺失、scope violation、overtest 导致实现细节耦合、`skip`/`xit` 占位或弱断言占位
- `[Minor]`：断言表述优化、测试命名偏差、非关键的重复或冗余
- `[Info]`：观察，无需动作

## 审查原则

- 只对照已批准的 `Test Scenarios` 审查，不自行从 `TechnicalSpec` 扩展新范围
- 只看测试断言是否正确翻译场景，不审查功能实现代码
- `[CRITICAL]` 场景优先
- 覆盖不足与过度测试同等重要
- 若问题会改变场景边界，指出应回到场景修订，而不是直接要求补写测试
