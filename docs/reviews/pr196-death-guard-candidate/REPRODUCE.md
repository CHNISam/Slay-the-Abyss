# 有限复跑

宿主使用既有native Lua5.4 runner，无安装依赖：

    cd /workspace/shared/sta-reactive-damage-review-0023/candidate-death-guard/candidate
    python ../run-lua.py ../lethal-incoming-probe.lua
    python ../run-lua.py ../reactive-order-probe.lua
    python ../run-lua.py ../death-guard-boundaries.lua
    python ../run-lua.py ../missing-player-hp-probe.lua

候选四项均应exit0：原负例Guardian204HP/1次反伤；原7组通过；6个guard边界通过；缺hp回调1次/targetHP6。

隔离负控，均应exit1：

    python ../run-lua.py ../mutations/remove_guard/run-lethal-incoming-probe.lua
    python ../run-lua.py ../mutations/remove_guard/run-death-guard-boundaries.lua
    python ../run-lua.py ../mutations/unsafe_state_access/run-death-guard-boundaries.lua
    python ../run-lua.py ../mutations/entry_only_guard/run-death-guard-boundaries.lua

分别检测原缺口、两处死亡终止、两种缺失上下文边界、队列中途死亡。负控只通过package.loaded覆盖本次独立进程的Actor模块，不写candidate源码。

基线红已保存；需要重新核原始源时，从上级recheck-9a4cf64-0103/head运行其原始7+1脚本，勿把candidate改回原源或覆盖作者分支。

新增兼容性负控应exit1：

    python ../run-lua.py ../mutations/missing_hp_type_check/run-missing-player-hp-probe.lua

同一probe的9a4原基线应exit0：

    python ../run-lua.py ../run-missing-hp-baseline.lua
