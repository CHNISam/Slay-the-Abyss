# PR238 Regen 回合末回归迁移

基线 `28869011`。完整 Lua 日志 `pr238-288-lua-121938913065.log` 中，`inventory_parity.lua:156` 的旧治疗事件识别断言失败；此前同一组的最终 44 HP、再生 9 层均通过。原 10 组中其余 9 组通过。依主线程要求沿用该真实 RED，不重复整组 RED。

固定源码 `319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 `RegenPotion.getPotency:45–46` 为 5；`RegenPower.atEndOfTurn:35–37` 排 TOP `RegenAction`；`RegenAction.update:31–43` 先治疗，再将玩家再生层数减 1。独立从固定 ZIP 读取的原成员 SHA256：

- `potions/RegenPotion.java`：`d71d06ab8711458b0dff3697e71d6e51f9678047ee0a04fc1e4681a0c13de823`
- `powers/RegenPower.java`：`624129a2e08864a2aa71e10515b9a13a0d4750d0ccadd95dc014b7132b35de34`
- `actions/unique/RegenAction.java`：`47b1e40452ee8976f1a019cae9e23ead98b0b251950647eede91159176853c92`

当前普通回合末的 `ownerEndRegen` 复用共享 `CardActions` 治疗，事件只有目标和实际回血量，不带旧 `Actor.tick` 的 `detail.status='regen'`。测试改按实际玩家治疗事件识别，保留双瓶 10 层、最终 44 HP/9 层，并强化为仅一次治疗 10、治疗帧 50 HP/10 层、敌回合起始帧 50 HP/9 层、受击帧 44 HP/9 层及严格事件顺序；cardRandom/misc 的两字随机状态和计数均不变。

只迁移测试，不修改生产队列、来源池、RNG、事务或旧 source lock。原夹具仍用正式药水定义及真实 Run.usePotion/endTurn，受控替换敌方 6 伤动作以隔离时序；它不是自然获取或完整原版/平台验收。既有 `owner_end_rollback.lua` 的全图失败回滚断言保持原样。

接手串行执行原完整inventory_parity.lua：10组全部通过，12570ms，沿用30000ms。原始输出在根build/pr238-resume-20261027-091929/inventory_parity-green.log；最终云端和平台范围按PR238集中记录分别报告。
