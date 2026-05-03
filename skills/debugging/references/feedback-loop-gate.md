# 反馈环 Gate 的判断规则

> SKILL.md §3.1 与 §5 引用本文件。把"裸跑 < 30s 且确定性 > 90%"具体化为可操作的校验流程。

## 阈值由来(不是经验值)

- **30s**:人在等待反馈时,30s 是"还能保持上下文专注"的阈值。超过 30s,debugger 会切到其他任务,假设 → 观测的反馈环被截断。这不是性能基准,而是反馈环的认知基准。
- **90%**:连续 3 次同模式失败的概率下界,对应"非偶然"判定。低于 90% 的 repro 进入 Hypothesise 后,Observation 阶段的"evidence"会被概率噪声污染,假设证伪失效。

两个阈值来源都是"反馈环可用性",不是任意工程数字。任何低于阈值的 repro 都视为**未通过 Reproduce gate**。

## 判断流程(机械可执行)

### Step 1:测量裸跑耗时

```bash
# 在干净环境连续跑 3 次,取 max
for i in 1 2 3; do
  /usr/bin/time -f '%e' bash .debug/<bug-id>/repro.sh 2>&1 | tail -1
done
```

- 三次最大值 ≤ 30s → pass
- 任一次 > 30s → **未通过**,回到 Reproduce 步骤把样本最小化(裁剪输入、关掉无关启动、用 fixture 替代真实 IO)

### Step 2:测量确定性命中率

```bash
# 跑 N=10 次,统计同失败模式次数
for i in $(seq 10); do bash .debug/<bug-id>/repro.sh; echo "exit=$?"; done
```

- "同失败模式" = 退出码相同 **且** stderr 关键 pattern 匹配 **且** 失败位置(行号/断言 hash)一致
- 同模式 ≥ 9 次 / 10 次(即 ≥ 90%)→ pass
- 同模式 < 9 次 → **未通过**,可能原因:
  - 并发竞争/时序依赖(seed 随机、网络抖动)→ 在 repro 里固定 seed、stub 网络
  - 测试隔离不足(状态泄漏)→ 在 repro 开头清环境
  - 真正的偶发问题 → 记录命中率 + 触发样本数,**不要**强行进入 Hypothesise;把"提高确定性"作为 Reproduce 步骤的子任务

### Step 3:连续 3 次失败模式一致

最简化校验,Step 2 已隐含;若用最小校验:

```bash
bash .debug/<bug-id>/repro.sh; echo "$?"
bash .debug/<bug-id>/repro.sh; echo "$?"
bash .debug/<bug-id>/repro.sh; echo "$?"
```

3 次退出码与 stderr 关键 pattern 完全一致 → 进入 Hypothesise。

## 未达标的处置

| 症状 | 处置 |
|---|---|
| `> 30s` | 缩小输入(用 1 条记录而不是全量 fixture);移除无关初始化;关掉非必要日志/网络 |
| 命中率 50%~90% | 把不确定性源固定:随机 seed、时间(freezegun/faketime)、网络(mock/replay)、并发(强制串行) |
| 命中率 < 50% | 这不是"难复现的 bug",是"现象未充分定位";回到 bug 报告,要求更具体的现象描述,而不是凭印象进入 Hypothesise |
| 修复前后退出码语义错位 | repro 自身复现 bug 时若期望非零,在脚本里用 `if ! <cmd>; then exit 0; fi` 包装,使"复现成功"=退出码 0,"修复后 bug 消失"=`<cmd>` 退出码 0,二者表达都是 0 但语义不同——更清晰的做法:repro 期望非零,修复后变 0,**且** Regress 测试以"修复后 0,修复前 ≠ 0"为契约 |

## 与"测试通过"的区别

`repro.sh` 的退出码语义是"现象是否被复现",不是"功能是否正确":

- 修复前:退出码 ≠ 0(bug 在,repro 命中)
- 修复后:退出码 0(bug 不在,repro 不再命中)

迁移到项目测试目录时(Regress 步骤),把测试改成断言"修复后行为正确",而不是"`repro.sh` 退出码"。`repro.sh` 留在 `.debug/<bug-id>/` 作为最低保底,真正的回归靠测试目录里的用例。
