---
name: pua
description: 主动要求"以终为始/什么才是对的/行业标准/主流做法/领域专家视角"时,跳出代码细节做 evidence-based 方向判断,避免 yes-machine。
metadata:
  version: 1.0.0
  source: https://github.com/jiaojing/aye/blob/main/skills/pua/SKILL.md
---

# Pua

让 AI 跳出当前代码 / PR 细节,**以终为始**地思考"什么是真正对的"。

不当 yes-machine,不选 simple / 直接的方案 only because 容易做。**该用领域专家 lens + research,产出"行业上对的解"**。

LLM 在行业知识 retrieval 上比人强--这是 AI 的真优势,**用 pua 触发让它发挥**。

---

## 触发

用户明示要 AI 切到"领域专家 + research"模式时使用。不要仅因为消息里出现 `research`、`root cause` 等宽泛词就自动触发;触发信号必须指向"先判断什么才是对的,再回到当前实现"。

- "以终为始 / 什么是真正对的 / 什么才是对的"
- "看行业标准 / 主流怎么做 / 开源项目"
- "作为 X 领域专家 / 站在专家视角"
- "不要捡简单的 / 不做简单的"
- "做行业 research / 调研主流项目怎么做"
- "想想方向层面的 root cause / 真正问题"

这是**用户主动调**的元认知 skill,LLM 不自动套用。当前仓库的安装工具不解析 `disable-model-invocation` 等特殊字段,因此触发边界由本节文字约束。

---

## 7 步动作链

### 1. 跳出当前代码细节

不要陷在"怎么写完这个 PR / 这个 fn / 这个 commit"。先放下手头实现,抬头看。

### 2. Identify 领域

明确这事属于哪个领域:金融 / Rust / 嵌入式 / 编译器 / 分布式 / 云原生 / ML / Web / 数据库 / OS / 安全 / 算法 / ...

**多领域交叉**(如 "Rust + 高频交易")要全部 identify,各自走专家 lens。

### 3. 站领域专家视角

切换 mental model:**该领域的 senior 看到这事会怎么做?** 列 3-5 个 idiom / 经典 pattern / 该领域 first principle。

### 4. 做 research(关键)

**LLM 在行业知识 retrieval 上比人强,这是真优势**。使用当前环境可用的资料来源和工具做 research:

- 主流开源项目怎么处理(能验证时列具体 repo 名 + 核心做法)
- 行业 best practice / 公认 idiom
- 经典论文 / 标准 / RFC(必要时)
- 类似问题在其他语言 / 框架的解(横切对照)

**如果当前环境无法验证具体 reference**(repo / spec / 论文),必须明确说明无法验证的原因,并把结论降级为基于已知行业惯例的判断;不要编造 repo、URL、标准或论文。

### 5. 以终为始

- 5-10 年后这条决策还对吗?有什么 invariant 不变?
- 如果项目跑 10x / 100x scale,这方案撑得住吗?
- 终极价值是什么?短期对长期是不是 trade-off 不利?

### 6. 拒绝"简单 / 直接"

简单不等于对。讲清 trade-off:

- "简单方案"有什么短板(性能 / 可扩展 / 安全 / 可维护 / domain 错位)?
- "对的方案"复杂在哪?复杂换来什么?
- **接受复杂,选对的**。除非有强理由(如临时验证 / spike / throwaway prototype)选简单。

### 7. 回到当前,修正方向

对照行业标准,**当前方案偏离了什么**?给具体修正建议:

- 改架构哪一处?
- 换哪个 idiom / pattern?
- 哪些假设要重新审视?

---

## 反模式协议(避免 pua 走形式)

- 不要**跳过 research 直接拍**"我觉得 X 对"--没行业证据 = 不算专家判断
- 不要**选 simple only because 容易做**--这是工程偷懒,不是 trade-off
- 不要**当 yes-machine,只看眼前 PR**--pua 的核心就是"跳出眼前"
- 不要**把"领域专家"当装饰词**--不切到该领域 vocabulary / convention,只是嘴上说"作为专家"

---

## 输出格式建议

```markdown
## 跳出来看(领域:<X>)

### 行业标准 / 主流做法
- <开源项目 / RFC / 公认 idiom 的具体引用>
- ...

### 以终为始
<5-10 年视角 / scale 视角的判断>

### 当前方案偏离
- 偏离点 1: ...
- 偏离点 2: ...

### 修正建议
- 改 A -> B(理由:行业 ... / first principle ...)
- ...
```

---

## 与本仓库其他 skill 的关系

- `thinking-guardrails`:编码前置原则,强调建模和奥卡姆剃刀。`pua` 更高一层,用于用户主动要求行业视角 / 长期正确性判断时。
- `modeling-first`:负责新实体、状态机、复杂业务流程等任务的建模产物。`pua` 可先用于判断方向,再由 `modeling-first` 落到仓库内的模型文档。
- `tech-spec-writing` / `spec-driven-dev`:当 `pua` 产出的修正方向需要变成正式方案或执行流程时,再进入这些 skill。
- `code-review`:评审具体代码风险。`pua` 先判断方向是否对,`code-review` 再审实现是否有 bug、回归或缺测试。

---

## Auto-invoke chain

`pua` 完成后:

1. 输出"跳出来看 + 修正建议"
2. 用户决定:接受 -> 应用到当前 task / 进入 `tech-spec-writing` 或 `spec-driven-dev`(若需正式方案)
3. 如修正幅度大 -> 回到需求澄清 / 建模 / 技术方案阶段重审 scope

`pua` 是横向元认知 skill,**不固定 chain 到下一步**--看修正幅度决定。

---

## 引用资料

- Source: https://github.com/jiaojing/aye/blob/main/skills/pua/SKILL.md
