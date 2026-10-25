# 循环与电动力学：球能力规则切片

固定来源 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，镜像声明V2.3.4/2022-12-18。社区反编译来源未经正版二进制认证；独立实现规则，不复制Java方法体、资产或文案。

## 来源核对

| 源相对路径 | SHA256 |
| --- | --- |
| cards/blue/Loop.java | 544833c3aa941f736e44c3f1d38de980c0e03e8b9837c6ea5ddbba24eb17fed3 |
| cards/blue/Electrodynamics.java | 0336bf31966a42b0eb77540b9bb83d2af643daf96bc20945276e3264adc64630 |
| powers/LoopPower.java | 58349487043b3185404e90282437d4ea7e1e2712b3a83b6285a7728bb26c5b8a |
| powers/ElectroPower.java | 724026eb61981771c8be1037d5f5da4064297c1d6f62342b5db0eab1ce16ae90 |
| powers/BiasPower.java | 35a183a0b16abc9c95d135fa4873d74ee9fdb7395b16ea57da06caaf399abc6a |
| powers/AbstractPower.java | 37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f |
| orbs/Lightning.java | 16458980840cc41d788b6d92c69e8f547aa8208eb34a37ee610dfbb7bdebe62e |
| orbs/Frost.java | 74c6f567c91c526b0fd2b9b8040888bab54eab329d099251ad94f81dadeb1439 |
| orbs/Dark.java | 610fccbaf45b74bf4c151982e07c599f940a295027271e478a4e8b3e46def373 |
| orbs/Plasma.java | 3758d5402fd24491fae363bf64fc4e871e917f5f89d44d2265840c96db648cce |

Loop是1费能力，普通1层、升级2层；每个玩家回合开始，仅首球额外触发对应层数次onStartOfTurn和onEndOfTurn。不是唤起，不移除球，打出当回合不立刻触发。Plasma只有start被动，Lightning/Frost/Dark只有end被动，因此每次Loop对各球只有一种实际收益。

Electrodynamics是2费能力，先施加ElectroPower，再依次生成2个闪电球，升级生成3个，费用不变。已有Electro不叠加伤害或层数；模型用非叠层布尔标记1表示存在，不能把它冒充源Power的amount（源继承默认-1）。生成导致满槽时，最早球的唤起已享受AOE。

## 不能简化的时序

LoopPower和BiasPower继承相同priority=5，AbstractPower.compareTo仅比较priority；Java Collections.sort为稳定排序，所以两者相对顺序保持首次获得顺序。叠加同名Power不重新排序。模型记录orbPowerOrder，只记录成功获得的Loop/Bias；Artifact挡掉Bias不记录。没有历史而同时存在两个状态时明确拒绝，不猜顺序；单一旧Bias fixture可作无歧义兼容。

但Bias.atStartOfTurn只排一个负Focus应用到BOTTOM，未立即扣集中。Loop同步调用首球被动：Frost/Lightning此时把旧集中对应的数值捕获到后续动作，Dark此时立即增加储伤。故先获得Bias仍不能提前降低Loop的本次捕获值；获得顺序影响的是稍后Focus状态事件与球效果事件的先后。例如Focus6，Bias先Loop后的冰霜动作捕获8格挡，实际执行时玩家集中已是5，仍得到8；Loop先Bias后则8格挡发生时集中仍是6。

收集所有Power hook后再收集正常Plasma开局被动，之后才按队列执行。Loop Plasma提供额外1能量，正常Plasma也提供1，均在普通抽牌之前；不要再调用旧Orbs.startTurn重复给能量。

Lightning的AOE标志也在动作创建时捕获。AOE执行不抽cardRandomRng，固定THORNS伤害不套用普通攻击力量/虚弱/易伤，不触发普通攻击反刺/Angry/CurlUp；仍走Combat.damage及群体death-reaction集合。未实现完整LockOn或所有敌人的非普通伤害钩子，不能据此声称原版全伤害事件完全一致。

Loop闪电在Power相位杀死末敌后，后面的Bias应用、Plasma GainEnergyAction和Draw被清理；Frost已排入的GainBlockAction仍保留。此区别来自GameActionManager.clearPostCombatActions保留HealAction/GainBlockAction/UseCardAction/DAMAGE的白名单，不是任意胜利全清或全保留。

## API与接入合同

`OrbPowers.withCards(data)`独立添加两张卡和完整中文状态定义，不修改既有Defect helper、生产数据或共享Profile。gainOrbPower使用status=loop/electrodynamics；Electro的各个生成分别是value=1的channelOrb，保留排队与末敌清理边界。

`apply(state,id,value)`复用Actor.applyPower，Loop成功应用后记首次顺序。`recordApplied(state,'bias')`须由共享applyBias成功路径调用。`startTurnPower(state,api)`替换旧的Focus.startTurn与Orbs.startTurn：同步收集有限Loop/Bias/Plasma hook，再执行，不能与旧hook重复调用。此函数不宣称实现任意其他同优先级Power/第三方钩子的通用调度。

`Orbs.preparePassive(state,index,'start'/'end')`捕获可排队的被动动作；Dark直接增长并返回nil。现有只读view保留，不因为读取界面而同步/修改规则。shared Combat事务须deep-save orbPowerOrder数组，避免后续卡牌效果失败污染首次顺序。

当前不支持在两Power间接入通用RemovePower/清除Bias后重新获得的完整顺序重建；应先补移除入口协议再开放相关遗物/卡牌。起始次序未知或构造非法状态明确拒绝，不静默选择一种结果。数值范围沿用有界signed32子集。

## 验证结果

使用root后续树`/workspace/sts-builds`的最新共享Actor/Combat/Effects接线同步到私树，保留根冻结树不变。执行：

- `node scripts/test-lua.mjs tests/lua/defect_orb_powers.lua`：27组通过。
- `node scripts/test-lua.mjs tests/lua/defect_orbs.lua`：原27组通过。
- `node scripts/test-lua.mjs tests/lua/defect_focus_build.lua`：原28组通过。

新测试通过真实Combat.play/C.endTurn验证普通/升级费用、Power离开牌堆、Loop仅首球与无立即触发、Plasma额外与正常被动在抽牌前、Bias获得序的Frost事件Focus快照、Dark同步增长、Electro先施加再满槽唤起AOE、独立随机数不消耗、非普通伤害不受力量/易伤/弱化及无反刺、死亡槽跳过、已有AOE标志快照、末敌清理，以及失败卡牌恢复原orbPowerOrder引用。少量低层API测试明确隔离Power相位的终局动作清理，不冒充整条自然通关。

当前只提供独立withCards；没有修改旧Defect helper、生产Profile、共享GameUI或发布清单。新gainOrbPower需要中文显示适配单独接入。没有全量suite、提交、推送、官方导入或Windows/手机实机验收。
