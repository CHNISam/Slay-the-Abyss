# 稀有遗物规则接入

原版依据固定为 STS1 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`，对应 `relics/` 下的23个类；飞翼短靴源类名为 `WingBoots`，冠军腰带为 `ChampionsBelt`。跨职责细节以 `ApplyPowerAction`、`GamblingChipAction`、`AbstractDungeon.returnTrulyRandomCardInCombat` 和 `AbstractCreature.decrementBlock` 为依据。

`abyss_rare_relics` 提供获得、永久牌组变化、战斗开始、回合、出牌、消耗、伤害、状态免疫、休息处及地图计数接口。持久计数保存在 `relicCounters`；单场标志在 `rareRelicCombat`，不会借用上一场的战斗状态。数据与源码身份一一对应，不缩小奖励池，也不在不支持时重抽。

关键次序：生姜/萝卜先于人工制品；鸟居处理格挡后2至5点普通伤害，再交钨合金棍；冠军腰带只由玩家向敌人成功施加易伤触发。针线为4层多层护甲，舵盘第三回合固定18格挡，石历第七回合结束无来源反伤型52点群伤，香炉每六回合1层无实体且计数跨战斗。

卡戎之灰是消耗遗物TOP群伤，枯木树枝是BOTTOM生成。后者在回调时从源common、uncommon、rare依序拼接、排除HEALING标签的完整牌池用 `cardRandomRng` 抽取身份，再于动作执行时创建临时实体；不会使用掉落奖励的 `cardRng`。能力牌正常移出战斗不算消耗。不休陀螺仅在真实动作队列为空、手牌空、仍有可抽牌且没有无法抽牌/选牌/回合结束时触发。

赌博筹码只在首回合普通抽牌后出现，允许选0张跳过；选中的真实UID完成弃牌及手动弃牌触发后，抽等量牌。怀表记录实际打出的所有牌，包括自动打出；首回合无额外抽牌，上回合不多于3张则额外抽3张。

铲子/烟斗/壶铃的休息处选项、飞翼短靴的跨边移动、转经轮的额外整份普通战斗卡牌奖励由Run调用对应接口。壶铃最多3次；短靴3次耗尽设为-2。可生成条件保持原版楼层限制及营火遗物最多2件的限制。

验证分层：`rare_relics_hooks.lua` 检查模块动作与计数；`rare_relics_run.lua` 用真实 `Run.obtainRelic` 和 `Run.startCombat` 检查取得后效果。它们均为离线证据，不代表官方导入、手机界面或实机验收。
