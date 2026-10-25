# 三职业实验开局数据

`abyss_character_profiles.prepare(data,id)`只准备独立数据副本，返回`preparedData,profile`，不创建Run或Battle，不执行遗物，不生成临时牌。支持`silent`、`defect`、`watcher`，其他值拒绝。`preparedData.experimentalCharacter`用于拒绝重复准备；`profile.experimental=true`明确完整卡池未开放。

## 数据及共享接入契约

| 职业 | 最大/初始HP | 永久初始牌组 | 唯一起始遗物 |
| --- | --- | --- | --- |
| silent | 70 | 5 strike_green、5 defend_green、survivor、neutralize | ring_of_the_snake |
| defect | 75 | 4 strike_blue、4 defend_blue、zap、dualcast | cracked_core |
| watcher | 72 | 4 strike_purple、4 defend_purple、eruption、vigilance | pure_water |

共同3能量、5抽牌、99初始金币。基础攻击/格挡牌均1费；攻击6→9，格挡5→8，升级不改费用。独立基础牌的`sourceId`分别为Strike_G/B/P、Defend_G/B/P，不能把独立ID当新自创机制。

准备函数先移除输入中的所有非状态、非诅咒牌，再使用相应职业已经实现的`withFoundationCards`；保留该职业有限子集和生成特殊牌，追加独立基础牌。不会把Ironclad常规池混进其他职业，也没有假造完整职业目录。状态/诅咒沿用已实现定义，其他职业合法跨色入口仍须独立实现。`data.cards.starter_deck.cards`仅含上述永久牌组，`data.rules.player.startingRelics`仅含本职业一个ID。原遗物目录完整保留并追加职业起始遗物，避免Black Blood等replaces引用成为悬空；Burning Blood定义存在不等于玩家拥有，三个职业都不会获得其战后回血。普通起始遗物仍须被既有随机奖励资格过滤。

`profile`含id、experimental、maxHp、energyPerTurn、drawPerTurn、startingGold、startingRelic、starterDeck、enableStances、enableOrbs，且与数据副本无共享可变牌组引用。`preparedData.characterId`和experimentalCharacter均为职业id。Run/Inventory集成负责把这些数据用于真实每战初始化与状态继承。

- 蛇之戒：`trigger=combat_start`，`effects={{op=draw,value=2}}`。固定源atBattleStart向队尾排入两抽，正常首手7。
- 破损核心：相同trigger，`effects={{op=channelOrb,orb=lightning,value=1}}`。固定源atPreBattle直接生成闪电球，必须初始化球槽后、正常开场抽牌前执行，每战一次。
- 至纯之水：相同trigger，`effects={{op=makeMiracle,value=1}}`。固定源atBattleStartPreDraw生成临时Miracle，正常首手为Miracle加5抽，共6张。Inventory不能仅因为三者trigger同名就统一放到抽牌后。

Neutralize为0费基本攻击，基础先3伤后Weak1，升级先4伤后Weak2。Miracle为0费COLORLESS/SPECIAL技能，无目标，selfRetain/exhaust均true；基础获得1能量、升级2，不含ethereal。它不是永久初始牌，不在奖励/商店常规池。其使用后消耗与回合末耗散不能混淆。

## 固定来源

所有路径相对社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。2026-10-25逐份只读核对方法语义后独立实现；不是官方开源或正版二进制认证。原始字节SHA256如下，既有六牌与姿态来源见WATCHER_STANCES.md及各职业专项文档。

| 文件 | SHA256 |
| --- | --- |
| characters/TheSilent.java | 905a13833d41785d9ad98fd1d882903e039d95676f60cdd723b8a10475b5b3f2 |
| characters/Defect.java | b327b7beaab109df7d638a9320d173e56e0be29bbbf667851c74b9f33b6656c0 |
| characters/Watcher.java | 14e466207588f1f7e747f86c32d7a00319f96dd3fbec7798996f4490b5255e17 |
| relics/SnakeRing.java | fd7f24f8b7b36ba2297cbfde1bf311aeed1e3daf2c01ecda9347064b2d8a062b |
| relics/CrackedCore.java | 7d0ba42928bb6e1d99f92e2b88a5f66b415b439e8b8a52bc853e1cf7f89a641e |
| relics/PureWater.java | 14d9c3c129e6801495d0333364d93d3413753fdf7fe29d30544b0241555128f1 |
| cards/green/Neutralize.java | c67ef7f8bbf84962da260d4a3395069067f1749500c8764b5bab84eafbc79861 |
| cards/tempCards/Miracle.java | 25cc7817d616acd13bb693303bac24e8251135f1feb89705bad53ac8497179e6 |
| cards/green/Strike_Green.java | 6325134c01e00e6d3ed957374de363e6f4ae5bb89b0ad20f373ed16124ff3e39 |
| cards/green/Defend_Green.java | 38963b10d208a04f56d11538d754edc6742ddd782caf1664b8a33fda7e858630 |
| cards/blue/Strike_Blue.java | 245b913fe88db2743103e06c3c11eee50683fa3de35f5b4632930480b479b614 |
| cards/blue/Defend_Blue.java | 9ebf52a97c48e0e5a84b149735f6de1dcd4efd9669ecd36da39d2cb79f75d636 |
| cards/purple/Strike_Purple.java | 45c3d8c61fc94f9b2b9eb411613ac00d04f3eb8705a47406bac6291f4d4372c2 |
| cards/purple/Defend_Watcher.java | 831f4ace374777d0b2f704d9ac6983487544e4447ecc2f9e2fad31ab1ca51668 |

## 定向验证和剩余边界

`node scripts/test-lua.mjs tests/lua/character_profiles.lua`执行12组通过：三职业基础属性/独立来源ID/全部初始牌能力门槛、源数据不变与副本隔离、无红池/不拥有旧起始遗物但完整保留遗物定义与replaces引用、真实Combat构造、Neutralize基本/升级伤害与Weak、Miracle保留/使用后消耗/能量、未知职业及重复prepare拒绝。

这些是明确数据夹具的验证；未在此套件触发Inventory遗物或Run真实自然开局。共享集成仍须验证职业选择、初始牌抽取、开场遗物时点、每战重置、跨节点状态及保存恢复。完整卡池、Boss通关、中文表现和千星平台实玩未验收。没有运行完整检查、提交或推送。
