# 公开回合命令的晚奖励失败回滚

共享回合末复审实证：Combat内部快照只覆盖核心命令；随后Run生成奖励失败时，原Run仍是combat、战斗已victory，结束回合或原选牌token无法重试。这是已有公开边界缺口，本轮Task16.1补齐，不将它描述为新阶段首次引入。

`Run.endTurn`和`Run.chooseCard`现在在调用Combat前复用既有完整Snapshot，覆盖药水/金币同步、永久变化和奖励生成。抛错恢复后继续抛出原错误；正常false原样返回并恢复，成功路径保持原返回值。原Run、Combat、牌、牌堆、队列、来源数据和随机流对象均保留，不换成克隆对象，不新增调度器或输入缓存。

新回归只通过公开Run命令取得卡和能量药水，使用seed42真实首个来源普通房间的52HP Cultist，不修改敌HP、能量或随机流。资源是明确授予的组件夹具，不计自然构筑通关。

- 结束回合：实际Omega+60造成来源胜利，奖励P.prepare先真实执行后抛错。
- 选牌：实际Juggernaut/FNP，Bludgeon32与Hemokinesis15将52HP敌减至5；Discovery真实选择后消耗、FNP格挡触发Juggernaut5击杀，随后同一真实奖励边界抛错。
- 两入口均核对每一个原可达表的字段及对象身份、非法token无副作用、原命令同token成功重试一次；最终完整状态与同输入无故障的独立Run逐字段/别名比较一致。

精确已到达晚失败的RED为两例均失败，日志`build/run-turn-reward-red.log`。修复后两例通过，`build/run-turn-reward-green.log`；原脚本30秒预算不改。静态105项历史警告，无新豁免，受管UI门槛保持。共享WLP暂停阶段的组合用例及完整CI随后按冻结源码复验；没有平台证据。
