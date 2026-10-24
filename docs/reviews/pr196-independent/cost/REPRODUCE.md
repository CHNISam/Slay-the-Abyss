# 复跑说明

使用已经存在的原生Lua5.4运行器，不安装依赖。将环境变量 LUA_RUNNER 指向现有 run-lua.py；下述所有路径相对本交接目录。

    export LUA_RUNNER=/path/to/existing/run-lua.py
    test -f "$LUA_RUNNER"
    python verify-frozen.py
    cd head
    node scripts/build-lua-data.mjs
    node scripts/build-ui.mjs
    python "$LUA_RUNNER" ../generated-cost-regression.lua

最后命令在冻结head应exit1，日志为expected3实际4。这是真正正确性断言，不是“错误签名等于预期”式绿测。

继续验证边界：

    python "$LUA_RUNNER" ../generated-cost-boundaries.lua

冻结head应exit1，11组中5败；该失败是已知缺陷，不是环境失败。

候选红→绿及有限保护：

    cd ../candidate
    node scripts/build-lua-data.mjs
    node scripts/build-ui.mjs
    python "$LUA_RUNNER" ../generated-cost-regression.lua
    python "$LUA_RUNNER" ../generated-cost-boundaries.lua
    python "$LUA_RUNNER" ../cost-target-contract-probe.lua
    python "$LUA_RUNNER" ../choice-contract-probe.lua
    python "$LUA_RUNNER" tests/lua/warrior75_edges.lua
    python "$LUA_RUNNER" ../baseline-choice.lua

候选以上命令应全部exit0。分别是生成费用正确、11边界、54非法目标/UID+4X费用+2临时升级+1能量拒绝、7种选择+49非法原子拒绝、原有39边界、原有真实控件选牌测试。

两张前置手牌/空牌堆以及单项状态布置是明确夹具。卡牌使用、生成随机流、结束回合及生成控件事件实际执行，但不代表自然获取前置牌或千星实机。

minimal-cost.patch只包含源文件4行。新测试如纳入仓库，应适配到现有测试目录并保留真正来源期望，不复制本地第三方参考方法体或调查脚本。
