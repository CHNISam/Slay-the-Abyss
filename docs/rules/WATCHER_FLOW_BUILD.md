# 观者姿态、占卜与回合流转候选

本切片独立新增`abyss_watcher_flow_cards`、定向测试和本文档。母表`CLASS_CARD_COVERAGE.md`中的18个候选均为N且源码模块未重复实现；不会将新切片计入前一阶段165张验证结果。以下规则来自固定[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)社区反编译镜像，不是官方开源、正版二进制认证或本轮原版实测。逐份核实后独立写数据与计划，没有复制Java方法体。中文是项目显示标签，保留英文名称/SourceID，未核原版简体本地化资源。

| 牌 | 稀有度/费用 | 基础 → 升级 |
| --- | --- | --- |
| Battle Hymn 战歌 | 罕见/1 | 下回合起每回合开始生成惩罚1；升级先天 |
| Collect 聚气 | 罕见/X，消耗 | 接下来X → X+1次能量恢复，各生成奇迹+1 |
| Fasting 斋戒 | 罕见/2 | 力量/敏捷各3 → 4，然后能量降低1 |
| Fear No Evil 无惧邪恶 | 罕见/1 | 8 → 11伤害；攻击意图则随后平静 |
| Indignation 愤慨 | 罕见/1 | 已愤怒则全体易伤3 → 5，否则愤怒 |
| Like Water 如水 | 罕见/1 | 回合末手牌处理前，若平静则固定格挡5 → 7 |
| Pray 祈祷 | 罕见/1 | 真言3 → 4，然后随机插入未升级洞见1 |
| Reach Heaven 直达天堂 | 罕见/2 | 10 → 15伤害，然后随机插入未升级以暴制暴1 |
| Study 研习 | 罕见/2 → 1 | 每回合末随机插入未升级洞见1 |
| Talk to the Hand 以手拒之 | 罕见/1，消耗 | 5 → 7伤害，然后施加格挡返还2 → 3 |
| Tantrum 暴怒 | 罕见/1 | 3伤害×3 → 4次，然后愤怒；原实例随机回抽牌堆 |
| Simmering Fury 酝酿怒火 | 罕见/1 | 下回合先愤怒，正常抽牌后抽2 → 3 |
| Wallop 当头棒喝 | 罕见/2 | 9 → 12伤害，按实际扣血给予固定格挡 |
| Wheel Kick 回旋踢 | 罕见/2 | 15 → 20伤害，然后抽2 |
| Wreath of Flame 火焰之环 | 罕见/1 | 振奋5 → 8，下张攻击每次普通伤害加成 |
| Pressure Points 点穴 | 普通/1 | 给目标印记8 → 11，再触发所有敌人已有印记 |
| Flurry of Blows 连打 | 普通/0 | 4 → 6伤害；实际切换姿态后从弃牌堆返回 |
| Weave 编织 | 罕见/0 | 4 → 6伤害；占卜非空抽牌堆时从弃牌堆返回 |
| Through Violence 以暴制暴 | 无色特殊/0，保留/消耗 | 20 → 30伤害 |

三个源码别名不能按类名改写：Fasting SourceID=`Fasting2`，SimmeringFury=`Vengeance`，PressurePoints=`PathToVictory`。复用既有Insight/Smite/Miracle定义，缺少时追加已核实的无色特殊定义；复用时校验其SourceID、费用、类型、保留、消耗与基础效果，不能悄悄复用同ID的另一种牌。

## 纯计划API与宿主边界

`withCards(data)`返回独立数据副本，只增加候选定义，不启动战斗或开放正式池。`ops`仅含8个外部新op：`gainWatcherFlowPower`、`applyWatcherFlowPower`、`fearNoEvil`、`indignation`、`collect`、`wallop`、`triggerMarks`、`flowDamage`。其余原生op复用既有解释器。`prepareEffect`与`planEffect`对未知op明确拒绝；只有内部`recallFlowCard`额外允许计划。Flurry/Weave/Tantrum使用`flowDamage`作为真实普通Damage的扩展入口，宿主缺少召回/清理接线时不会静默当成已完整实现的普通攻击。

* `prepareEffect(state,effect,target)`返回一份effect，冻结普通伤害`normalAmount`；不是固定伤害，不得绕过普通攻击的格挡、反击和被攻击回调。`adaptDefinition`目前原样返回：本批没有实例永久成长。Vigor由`damageBonus(state,owner,damageType)`接入Actor NORMAL Power链，不能乘Heavy Blade的力量倍率。
* `planEffect(state,effect,context)`返回纯`{top={effects},bottom={effects},consumeAllEnergy=false}`。每个数组都按执行顺序；宿主压TOP时逆序。额外`applyPower`描述符给出status/value/targetId，宿主先按DEBUFF类型判Artifact，再用`applicationPlan`确定存储值。Wallop的`damage`描述符表示先走真实Damage，再调用`planWallop(lost)`排TOP固定Block；宿主也可显式处理这两类描述符。
* Fear No Evil执行时查目标攻击意图，TOP排列为Damage在先、Calm在后。最后敌人被击杀会清除后续Calm。不能先变平静再计算本次伤害，也不能把意图条件冻结为构造时的状态。
* Indignation执行时才查当前姿态，**BOTTOM**追加逐敌ApplyVulnerable或Wrath。因此原生UseCard可先完成，之后才变姿态/易伤；不能为了方便改成TOP。逐敌动作携带targetId，不能因死敌槽位而偏移目标。
* Collect使用`context.energyOnUse`，-1/未给则用执行时能量；升级值为+1，效果正数时才BOTTOM施加Collect并请求宿主消耗当前所有能量。Chemical X明确拒绝，`freeToPlayOnce`只按已核Source字段处理，不引入未实现的费用能力。Collect层数是**持续回合数**，每次`energy_recharge`只生成1张Miracle+，随后BOTTOM减层/移除。不是一次生成X张。
* Pressure Points先施加DEBUFF Mark（Artifact可挡），然后`triggerMarks`读取当前各敌人已有Mark并BOTTOM排`markLoseHp(targetId,value)`，在原生UseCard之后生效。阻挡了本次新印记仍会触发已有印记。HP_LOSS无视格挡/力量/虚弱/姿态，source owner=null；宿主需走恰当的HP_LOSS事件语义，不能借会消耗格挡的普通fixed伤害。
* Wallop调用真实伤害后使用扣血量。源AbstractMonster.damage设置lastDamageTaken=min(减去格挡及Power后的伤害,currentHealth)，所以过杀量不能额外给格挡；Block固定、不受敏捷/脆弱影响。GainBlock在clearPostCombatActions中保留，因此末敌死亡仍保留已排格挡；玩家死亡不因此获救。

## Hook的精确阶段

`planHook(state,id,phase)`只接受`energy_recharge`、`turn_start`、`turn_start_post_draw`、`turn_end_pre_cards`、`turn_end`；未知阶段拒绝。宿主必须按全局Power priority及同优先级获得顺序调用，不能把此模块所有Power集中挪到其他能力之后。新Power默认priority5，DrawCardNextTurn为20。

BattleHymn与EnergyDown、WrathNextTurn在preDraw阶段构造BOTTOM动作；LikeWater在`atEndOfTurnPreEndTurnCards`检查Calm，并排固定Block，发生在retain/ethereal/自动弃牌之前；Study在atEndOfTurn随机插入Insight。DrawCardNextTurn在postDraw排Draw然后移除，NoDraw只会阻止Draw，不阻止移除。WrathNextTurn先排Wrath再移除，不因已处于Wrath而重复姿态收益。源WrathNextTurn的amount=-1是内部哨兵，本ABI存presence=1并明确`sourceSentinel=true`，不把此数字冒充原版层数。

**能量恢复构造时点**：GAM先调用applyStartOfTurnRelics/Powers构造preDraw动作；接着构造`DrawCardAction(...,true)`，其构造器创建PlayerTurnEffect。后者立刻energy.recharge并调用各Power.onEnergyRecharge，Collect的生成/减层因此追加到已有preDraw尾部；随后GAM才把正常Draw入队，构造postDraw动作。可见执行顺序为preDraw Power动作 → Collect生成/减层 → 正常Draw → postDraw。能量已在Draw构造期间重置，排在队首的EnergyDown实际减少新回合能量；不能把Collect生成抢到BattleHymn前面。

Fasting三动作依序Strength→Dexterity→EnergyDown。EnergyDown、BlockReturn、Mark为DEBUFF，须进Artifact判定；前两个正Strength/Dex增益不花Artifact。`applicationPlan`在Artifact预测之后检查overflow；Collect构造与stack都cap999，LikeWater构造不cap而只有后续stack cap999（甚至已有2000会降到999），其余正常正层数不猜测隐含上限。所有新状态由Combat.new自然清空，不写入永久牌组或跨战斗成长字段。

`planUseCard(state,card)`给出Vigor的BOTTOM移除，发生在该卡原生动作之后、UseCard收尾之前。先构造攻击各击伤害快照，再排移除；多段每击都得到加成，不只第一击，也不影响技能、THORNS或HP_LOSS。`dontTriggerOnUseCard`不触发移除。宿主需把Vigor放在普通伤害Power阶段，不能在源卡基础伤害或力量倍率上改写数值。

`planAttacked(state,owner,context)`实现BlockReturn：source非空且不是owner、damageType=NORMAL时即TOP排固定Block；**0伤害和完全被格挡仍触发**，不要求实际扣血。THORNS/HP_LOSS不触发。TalkToTheHand先伤害后Apply，所以新加的标记不为它自己的首击回格挡，旧标记照常有效。

## 召回与原实例回牌堆

`planStanceChange(state,old,new)`只在成功实际改变姿态且state.player.stance已赋新值后调用，遍历discard底到顶，逐张Flurry排BOTTOM召回；排在Power/遗物/旧姿态退出/新姿态进入所排的收益之后。相同姿态不召回；CannotChange需在宿主提前阻止这一回调。

`planScry(state,eligible)`中eligible表示该次Scry开始时draw非空，而不是选完后的剩余张数。Scry先触发Power.onScry；空draw直接返回，不触发Weave。非空时首次打开选择与完成弃牌后分别遍历discard，故本次刚被Scry弃掉的Weave也可召回，零选择仍允许原来discard中的Weave；把全部候选弃掉后eligible仍为true。重复UI tick排出的同UID动作在实际执行时因已离discard而自然无效，不能重复生成牌。无draw且Nirvana仍触发的旧规则继续保留。

`recallFlowCard`必须等动作执行时再检查UID是否仍在discard且手牌<10，返回`move={from='discard',to='hand',uid,handHook=false}`；满手则不移动。源DiscardToHandAction直接移动并applyPowers，没有onDrawOrDiscard，不冒充Draw、更不触发手动弃牌效果。

Tantrum通过`disposalPlan(state,instance,exhausted)`把**同一个**使用实例随机插回draw，保持UID/升级与实例费用字段；exhaust优先，不复制新牌。源UseCard→CardGroup.moveToDeck→Soul.onToDeck→addToRandomSpot：空draw不耗RNG；非空n调用cardRandomRng.random(n-1)，Lua插1..n，不重洗其他牌，不插新尾top。与既有生成牌插入使用同一独立cardRandom流。Source的Rebound清理优先级高于shuffle；本切片未实现Rebound/Strange Spoon/卡牌复制等复合，宿主若未支持这些能力应明确拒绝，不覆盖其处置结果。MasterReality生成升级仍属未支持组合，沿用共享显式guard。GoldenEye不在此切片实现范围。

## 验证与当前缺口

`node scripts/test-lua.mjs tests/lua/watcher_flow_build.lua`在238张Profile的sts-flow基线上27组全部通过（约2.7秒）。测试包含真实Wallop挡致死Thorns（HP4、Thorns7：先格挡9再反伤，HP仍4、剩Block2）及完全格挡时不给Wallop格挡的致死对照。耗尽Artifact沿用共享ABI的0值，测试允许nil/0表达耗尽，但仍严格要求EnergyDown未施加且Strength/Dexterity实际增加。Scry两阶段Weave召回、先洗抽回原牌后的幂等召回、Tantrum各击Vigor与原UID回堆均已通过真实Combat验证。

收尾全量日志`build/card-flow-full-check.log:8261–8271`暴露测试夹具重复追加Flow：新Profile已包含BattleHymn，旧prepared()仍无条件withCards。修正仅在Profile尚无BattleHymn时追加helper；18张定义完整性断言及重复withCards必须拒绝的测试保持不变。没有降低断言或修改runtime。全量日志中其余七个Watcher fixture已通过，本轮只定向复跑失败文件；未重复运行全量、执行未来未接的Final候选或宣称平台实机通过。展示文件另由独立切片接入。

### Wallop与Scry精确队列复审

源[WallopAction:37–39](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/WallopAction.java#L37)先调用target.damage，返回后才addToTop GainBlock。damage内部[AbstractMonster:652–655](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L652)遍历onAttacked，[ThornsPower:45–48](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java#L45)已先addToTop反伤。后压的Wallop Block因此在反伤前执行，能挡本次Thorns；不能在返回WallopAction前立即打掉玩家HP再补Block。

[ScryAction:37–65](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/ScryAction.java#L37)不是仅在action终结时回调：首update的55行open grid后，同次update的62–64行立即遍历当前discard.triggerOnScry；选完后的update在56–60行先移动选择牌到discard，再到62–64行回调。打开UI期间[AbstractRoom:254–255](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L254)停止actionManager update；关闭后duration未耗尽的额外tick还可能重复排动作，不能把UI每帧都算作一次立即召回。

[Weave:33–34](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Weave.java#L33)明确addToBot DiscardToHandAction，不是TOP。原生CTF后续Draw与UseCard、已排Nirvana固定Block均先于这些BOTTOM召回。测试在选择暂停时检查Power Block已在Weave召回前入队，再确认原生抽牌/清理和Nirvana之后原Weave返回。

[DiscardToHandAction:23–32](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/DiscardToHandAction.java#L23)执行时检查原card仍在discard且手牌未满，再移动同一对象并remove原discard元素。因此CTF选择draw最后一张Weave弃掉后，紧接的Draw会先洗入并抽回它；随后已排召回因它不再在discard而无效。新增真实测试检查这个UID在全部牌堆中只出现一次、nextUid不变，不允许再次append原对象制造重复。

## 固定来源与原始字节SHA256

每个链接均固定同一提交，不混浮动master或后续版本。

| 源文件 | SHA256 |
| --- | --- |
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [actions/common/DrawCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java) | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| [actions/common/GainBlockAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java) | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| [actions/common/GainEnergyAndEnableControlsAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainEnergyAndEnableControlsAction.java) | `1011bf2936fd4d02bdd28f3e1398720db9919c07441013c2c3ec8c243492adc7` |
| [actions/common/LoseHPAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/LoseHPAction.java) | `50c9ea9f1aef4a02ff9177d59517f61b03941e9770a23bc50bed8e3d60d69670` |
| [actions/unique/LoseEnergyAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/LoseEnergyAction.java) | `c9e2e5b9516fda59b6caf662d72cbf12edac26bea24c49e780f46275ad468820` |
| [actions/utility/DiscardToHandAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/DiscardToHandAction.java) | `b0747e280d603d8748cdaf30c91402017991a89d4039d254e940f63529a01adf` |
| [actions/utility/ScryAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/ScryAction.java) | `a22d8875a9ac3a4b6c445abad65a6ca4defa8fb309d1f6a6e51506a8e3b55147` |
| [actions/utility/UseCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| [actions/watcher/ChangeStanceAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/ChangeStanceAction.java) | `47392dbaacb9627f88f047008cbe7fb90b550acae1f491099470f1d2d080e877` |
| [actions/watcher/CollectAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/CollectAction.java) | `d5ed10508aa74bb4448b6f817086bcea7a48bb8335a3bad920ba746e5ac7d605` |
| [actions/watcher/FearNoEvilAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/FearNoEvilAction.java) | `bfa87723e66df88fe5d0d90e165b09c61b02a1ee9d7d1f8b08d6b4ce169d5f25` |
| [actions/watcher/IndignationAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/IndignationAction.java) | `0316a91cbbcdfd76cca0fbd0e90bae4ea4aa462de9e6e7c03afebc47e77dc9d5` |
| [actions/watcher/TriggerMarksAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/TriggerMarksAction.java) | `31ec2f470bb59a063d3811501d58a1f30167dd705b76f0ce38b8d5301df1ca1b` |
| [actions/watcher/WallopAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/WallopAction.java) | `6822f5925e63e0ca11ba1b6793761444834f442a40a81e1877c71940725e3bb1` |
| [cards/AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [cards/CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [cards/Soul.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/Soul.java) | `8e4105a9df83d93ad4f66d35c54b63720e90f71b80c7594a6faa454d19b545c0` |
| [cards/SoulGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/SoulGroup.java) | `c3b44b69f2ebcff77b8a1d49c492973900cc42d597d66c651c4f41399af031cb` |
| [cards/purple/BattleHymn.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/BattleHymn.java) | `2f30096b645c8d02039f3e415e4fa2ba7cd2b741d8d3d79eab1b6f58834b09c0` |
| [cards/purple/Collect.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Collect.java) | `9dbd590c810f7223219faa10cfef8dd32bfb3c95c59cb1cbf493c9b869dfedc6` |
| [cards/purple/Fasting.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Fasting.java) | `ce4f2d63467a7424155b3c6c3979b2fbee9bf06a40aaa886872a8f2c46e343c6` |
| [cards/purple/FearNoEvil.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/FearNoEvil.java) | `e7c27395cbcdd36516466c0e97d49099698e12d74205a11f2c59b4db5ef425ee` |
| [cards/purple/FlurryOfBlows.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/FlurryOfBlows.java) | `30f6f906d3bf99eae58b9c6efc36cf3d8f0ce1fdf3aed73146862ea14a07328d` |
| [cards/purple/Indignation.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Indignation.java) | `addc6968501d0d36190062be02d012a65ab05eac24c14ee7dc6dd79ef0442504` |
| [cards/purple/LikeWater.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/LikeWater.java) | `c1412dcc5b76cf3d071cdb215c949bbeb5b8463556ccdfd40900037fbbdae117` |
| [cards/purple/Pray.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Pray.java) | `03ff07a74b3b8fd001ab5974d342c408ef9451ed6412823e44cd09c0efc1c404` |
| [cards/purple/PressurePoints.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/PressurePoints.java) | `a90a936fca1c52baa0fb70d6b0095a313500d7d82077d8e8619af009df901e70` |
| [cards/purple/ReachHeaven.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/ReachHeaven.java) | `340ed7c3403836d224ed4d3dcc51f9cac0ddc62c1f841fbf51288ea652211c1c` |
| [cards/purple/SimmeringFury.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/SimmeringFury.java) | `5d9b564c68a85d74a679fc41a041bdacfec95de0511f989a74f1ea5573dd1eae` |
| [cards/purple/Study.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Study.java) | `e98b7fc67df92270906e9a734be893ad9585633368a969b08f4d41d9a9bcff2d` |
| [cards/purple/TalkToTheHand.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/TalkToTheHand.java) | `301afcd6e71ce64ab1398142cfd219d11aa33ae4b2554422339d9ae34ac2abbf` |
| [cards/purple/Tantrum.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Tantrum.java) | `c518a78773408da8bec624b380af0b69d4a60ef17e1e5e93328958a11a8a311d` |
| [cards/purple/Wallop.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Wallop.java) | `889a8570baf3d9655766242933864cdc025bd90aa21ffd5cc9c5804fcbffa046` |
| [cards/purple/Weave.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Weave.java) | `c6019a97a8eada05b2246be97b0103e1a4ead3ae6fc5c26ce8b555a955c6f42c` |
| [cards/purple/WheelKick.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/WheelKick.java) | `0938e44c05d9756870f97f5d576fbe881299b357af915ff0b39c4c827a484a92` |
| [cards/purple/WreathOfFlame.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/WreathOfFlame.java) | `484f20c333f5c2139c8313767baa10dab125e629359c4caa8a3f7a244fb07592` |
| [cards/tempCards/Insight.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/Insight.java) | `0bc12e832eb57dd7c969da15c0f3c45b9d1d91ab4c768179806669c43b637008` |
| [cards/tempCards/Miracle.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/Miracle.java) | `25cc7817d616acd13bb693303bac24e8251135f1feb89705bad53ac8497179e6` |
| [cards/tempCards/Smite.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/Smite.java) | `849c5aa27648f5c6a6fc361e6ef48b25bc528e9df7652d49ffcfb5385241010e` |
| [cards/tempCards/ThroughViolence.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/ThroughViolence.java) | `d86a3b457ce443f8818daf0f28cc658b546cca453cb66db50594b998243d6c95` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [core/AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java) | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| [core/EnergyManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/EnergyManager.java) | `82c676fdd86d3b409cd7bc38c294e65ee6c2b3a2bea5bce38a8bf98d56dd4383` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [powers/AbstractPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java) | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| [powers/CollectPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CollectPower.java) | `deff9876018816d1043bbf4de3eed9aa3ac2d4c246624029c5411a11dae5a877` |
| [powers/DrawCardNextTurnPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DrawCardNextTurnPower.java) | `7f43052db3e11d82b83b24753cac3eedd81a162eedf20465288a16bda2118407` |
| [powers/watcher/BattleHymnPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/BattleHymnPower.java) | `c80a6d1b5821fee7aae75c268dc7423c8a0b099bfce129d89944e50fa23e1707` |
| [powers/watcher/BlockReturnPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/BlockReturnPower.java) | `a9b1b60a5481bed13e01ac4b14185170f390af5487375edc8f181caaa4f2516b` |
| [powers/watcher/EnergyDownPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/EnergyDownPower.java) | `c8c9f2ee50fa43235155ece95fb4ad0b942d6dddf659824e3b69c79258ddb054` |
| [powers/watcher/LikeWaterPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/LikeWaterPower.java) | `4937bfbeea389f71ba3e80b5cd3232073d5a7b68a04f0bc5bec885951643ef4f` |
| [powers/watcher/MarkPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/MarkPower.java) | `dcb3b7838640c189682889a67b37ddb6bae4df3ca2b219375b74a9a737f5a209` |
| [powers/watcher/StudyPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/StudyPower.java) | `0c85e3a7b1b42444b46b9765f9319af5e16444cd51173e6638b76db249a0419c` |
| [powers/watcher/VigorPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/VigorPower.java) | `69be286a6cc8e6c86cc21e131c0a2022cccd5a89f7ba740df694fb70bf356465` |
| [powers/watcher/WrathNextTurnPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/watcher/WrathNextTurnPower.java) | `87e8452fefb0ea8d4a16d0128d9282795105aa88902f0dc452de39a606291258` |
| [rooms/AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` |
| [vfx/PlayerTurnEffect.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/PlayerTurnEffect.java) | `014ddd04c526de9d81b15a4080f80cf0c04e0f3243b60fcb208cdaab9ced4d0d` |
| [powers/ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | `78ce7c63874a3539f03c50a9cdfdf8bcfba7b47e73bce18c10672e5bad3ae87a` |
| [actions/AbstractGameAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/AbstractGameAction.java) | `cf0e5dbdfdf3f0c567c3527b839070718e19d836bb62364e8fa5f973b5ecdccb` |
| [actions/common/DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
