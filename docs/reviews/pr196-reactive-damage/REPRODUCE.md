# 有限复跑

本目录内已复制既有native Lua5.4 runner，无需安装依赖。需要宿主已有 `/usr/lib/x86_64-linux-gnu/liblua5.4.so.0.0.0`、Python3、Node。

    cd /workspace/shared/sta-reactive-damage-review-0023/head
    node scripts/build-lua-data.mjs
    python ../run-lua.py ../reactive-order-probe.lua

预期 exit0：7 cases, 0 failed。

    python ../run-lua.py ../lethal-incoming-probe.lua

固定f93预期 exit1，因真实缺陷而失败：预期guardianHP204/反伤1次，实际guardianHP200/反伤2次。玩家HP0/Run defeat/无奖励均相同。该脚本不是应全绿的现状检查，修复后才应exit0。

develop826不具备Flame Barrier卡/状态/handler，原样反例未执行；没有混入PR196源码来伪造develop负例。完整固定身份见develop-comparison.json。

未进行全量npm、49/75全扫、Windows检查或平台操作。
