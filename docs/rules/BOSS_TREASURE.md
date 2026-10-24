# 第一幕 Boss 宝箱的有限支持池

本切片接通第16层 Boss 战后卡牌奖励 → 地图上的独立第17层 Boss 宝箱 → 领取一件或明确跳过 → 胜利页。第16层获胜不再等于全局胜利。只支持三件确实有运行时效果的 Boss 遗物；这是首发受限内容池，不是完整原版遗物池或原版抽样概率认证。

## 来源和可信边界

2026-10-24 只读核实社区反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`。镜像声明 V2.3.4 / 2022-12-18，但未经正版二进制 hash 认证；不称官方源码或本轮原作实测。未复制或执行其实现。

- [BossChest 构造器和 open](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/rewards/chests/BossChest.java)：三件 Boss 遗物、独立选择界面，不能以普通宝箱替代。读取内容 UTF-8 SHA256：`599664F42E5CA805958958197EA1A7E045C9F6DA397D1BFA35C1346248FB289F`。
- [BlackBlood canSpawn/onVictory](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/relics/BlackBlood.java)：持有 Burning Blood 才能出现，存活胜利回复12。读取内容 SHA256：`8AB7671B5A6283548E8B3E23B3E0ABAF02B40DC515E63AD4E779FF220CC41205`。替换起始遗物的说明另由[Black Blood 条目](https://slay-the-spire.fandom.com/wiki/Black_Blood)交叉核对；镜像 `AbstractRelic.bossObtainLogic` 将它排除于普通 obtain，选择屏幕方法体本轮未取得，不外推替换动画时序。
- [SlaversCollar beforeEnergyPrep/onVictory](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/relics/SlaversCollar.java)：精英房或有 Boss 的战斗准备时能量上限加1，胜利撤回。读取内容 SHA256：`2201D18D9701CEADCC47757961A8D5EAE95DBFC1581496BE3D108469F16EDB89`。
- [Sozu onEquip/onUnequip](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/relics/Sozu.java)：能量上限加1。SHA256：`B977EE5E71F3DBBEE32A6F68ED7629D6961AB5A91EAF0856B3636B11AD638093`。
- [RewardItem 药水领取分支](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/rewards/RewardItem.java#L439)和 [StorePotion.purchasePotion](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/StorePotion.java#L83)：Sozu 阻止获得药水，商店不扣金币；已有药水仍可使用。读取内容 SHA256 分别为 `2F160DADBF2F0345BBC321B9036E6EBDF0FAE6B3CE60B87702B2B6E762F6A33C`、`3D92C1023E0B8BEB564597884625D94D76A3291872DABA091BBBA94241592A8E`。

## 独立实现和接口

`Nodes.enter` 只允许已完成 Boss 战后卡牌事务的 Run 进入真正第17层宝箱。待选状态为 `phase=node`、`nodeFlow.type=treasure`、`roomKind=boss_treasure`、`reward.relics={id...}`；普通 `claimTreasure` 拒绝此房。`claimBossTreasure(run, choice)` 接受1起算的候选位置或0明确跳过；合法领取和跳过都单次进入 `phase=victory`，结果为 `boss_treasure_complete`。非法、重复及失去前提的领取不修改库存、金币、牌组或 RNG。

候选仅来自受支持 Boss 遗物，排除已持有项；Black Blood 要求仍持有 Burning Blood，领取时原位替换，不叠加6与12。普通商店与普通宝箱排除 Boss rarity。用本项目既有 LCG 对受限池无放回抽取最多三件；池不足时只列合法项，允许跳过，不拿普通遗物补位。原版整池、池耗尽特殊回退、独立 relicRng 及完整随机消费交由后续规则审计，不能据本片宣称一致。

能量遗物在每场 `Run.startCombat` 生成独立规则副本，Sozu 每战加1，Collar 仅精英/Boss加1；Combat 的首回合和后续回合读取同一战斗副本，Lantern 仍只加首回合，不污染数据或下一场普通战。所有正常药水获得路径应汇入 `Run.obtainPotion`，其 Sozu 拒绝发生于写入槽位前；禁止直接写入库存绕过。暂未实现的商店/事件药水来源不在本片伪造。

## 回归与验收边界

新增 `tests/lua/boss_treasure.lua` 验证17层独立事务、三领取/跳过、非法/重复拒绝、替换前提、普通池隔离及新局清空；`boss_relic_effects.lua` 用真实战斗入口与回合命令核能量、条件叠加、已有药水使用与新药水拒绝，并明确隔离胜利/失败末态核12点回复。每个新文件显式15秒执行通过。原有 nodes/run 回归也在15秒内通过。

宝箱测试为了隔离事务使用导航末态和 Boss 战斗末态夹具，没有降低生产 Boss 数据。这些测试不是正常17层通关证据。未运行原神、MCP编译、写档、官方导入、正式胜利结算或重新挑战；UI接线、真实17层通关与平台结算仍须统一候选独立验收。
