#!/usr/bin/env bash
# bug-id: <bug-id>          # required, 与 .debug/<bug-id>/ 目录名一致
# 现象: <一句话>
# 触发样本: <input fixture / 命令 / API call>
# 期望:
#   修复前: 退出码非零 (或 stderr 含 <pattern>)
#   修复后: 退出码 0
# 反馈环约束: 裸跑 < 30s, 连续 3 次失败模式一致 (确定性 > 90%)

set -euo pipefail

# 切到 repo root,使脚本不依赖调用方 cwd
cd "$(dirname "$0")/../.."

# --- (可选) 准备阶段 ---
# 复制 fixture / 启动一次性容器 / 设置最小环境变量
# 不要从 .debug/<bug-id>/ 之外读取临时文件;依赖 fixture 时把 fixture 也放进 .debug/<bug-id>/

# --- repro 命令 ---
# 用最短能命中失败的命令/测试调用替换下一行(去掉占位注释)
# 例:pytest tests/test_foo.py::test_bar -x  或  ./bin/run --input .debug/<bug-id>/sample.json
: "REPLACE_WITH_REPRO_COMMAND"

# --- 退出码语义 ---
# set -e 会让任一非零自动传播;若 repro 自身命令期望非零退出码作为"复现成功"信号,
# 请用 if ! <cmd>; then echo "reproduced"; exit 0; fi 包装,避免误把"复现成功"当作"测试通过"。
