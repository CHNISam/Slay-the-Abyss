# 有限独立复跑

使用既有 liblua5.4，无安装。所有命令在本审查目录执行。

## 最终 v2：均应 exit0

    cd /workspace/shared/sta-death-guard-review-0112/candidate-v2
    python ../run-lua.py ../lethal-incoming-probe.lua
    python ../run-lua.py ../reactive-order-probe.lua
    python ../run-lua.py ../death-guard-boundaries.lua
    python ../run-lua.py ../independent-reentry-cleanup.lua
    python ../run-lua.py ../missing-hp-callback-probe.lua
    python ../run-lua.py ../v2-missing-player-hp-probe.lua

前五条分别覆盖1、7、6、9、1个不同场景，共24；第六条为作者提供的等价缺HP脚本，不重复计入覆盖数。

## 原始基线

    cd /workspace/shared/sta-death-guard-review-0112/baseline
    python ../run-lua.py ../lethal-incoming-probe.lua
    python ../run-lua.py ../reactive-order-probe.lua
    python ../run-lua.py ../death-guard-boundaries.lua
    python ../run-lua.py ../independent-reentry-cleanup.lua
    python ../run-lua.py ../missing-hp-callback-probe.lua

按顺序预期 exit1、0、1、1、0；分别是原致死负例、7组稳定、6边界2败、9独立组3败、缺HP旧回调可用。

## v1 兼容性退化红证据

    cd /workspace/shared/sta-death-guard-review-0112/candidate
    python ../run-lua.py ../missing-hp-callback-probe.lua

应 exit1，attempt to compare nil with number；v1不是最终交付。

## 最终 v2 的真实负控：均应 exit1

    cd /workspace/shared/sta-death-guard-review-0112/author-v2-frozen/candidate
    python ../run-lua.py ../mutations/remove_guard/run-lethal-incoming-probe.lua
    python ../run-lua.py ../mutations/remove_guard/run-death-guard-boundaries.lua
    python ../run-lua.py ../mutations/unsafe_state_access/run-death-guard-boundaries.lua
    python ../run-lua.py ../mutations/entry_only_guard/run-death-guard-boundaries.lua
    python ../run-lua.py ../mutations/missing_hp_type_check/run-missing-player-hp-probe.lua

负控失败是预期检测，不是候选失败。完整历史退出码见 run-results.json。
