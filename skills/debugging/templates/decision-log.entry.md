# `.debug/<bug-id>/decision-log.md` 条目模板

> 每步追加一段,**不覆盖历史**。三类块按时间顺序追加,时间戳必须单调递增(用于校验 `Invariant.DebuggingSkill.2` 的 5 步顺序)。

## Hypothesis @ <ISO timestamp>

- H1: <一句话假设> — falsify by: <如何用 repro 区分/证伪,例如"加日志看 X.method() 的入参">
- H2: <一句话假设> — falsify by: <如何区分>
- H3: <一句话假设> — falsify by: <如何区分>

> 候选 ≤ 3 条;每条必须配显式证伪策略,不允许"凭印象选 H1 直接进 instrument"。

## Observation @ <ISO timestamp>

- instrumented: <插桩位置/方式,例如"在 module/foo.py:42 加 log.debug(arg)">
- evidence: <repro 输出片段,贴最少够定位的几行,不要全量日志>
- verdict: H1=ruled-out, H2=confirmed, H3=pending

> 至少一条假设被证伪或被观测确认才能进入 Fix。
> 插桩必须只读,不能修改行为(否则属于 Fix 而非 Instrument)。

## Fix @ <ISO timestamp>

- root-cause: <被确认的假设标号 + 一句话根因,例如"H2: 缓存键漏掉 tenant_id 导致跨租户读到旧值">
- changed: <文件:行号 的改动摘要,例如"src/cache.py:18 添加 tenant_id 进 cache_key">
- verified-by: repro before=fail, after=pass

> "verified-by" 必须由外部可验证,不能仅凭"我跑了一下";
> 进入 Regress 步骤时,把 repro 升级为长期回归测试,并 emit `ReflectionEligibleEvent`。
