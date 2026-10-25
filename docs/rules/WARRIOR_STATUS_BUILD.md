# 战士状态牌、整手消耗与受伤降费

本片仅新增独立helper、测试与本文；不修改默认JSON、已有phase3交付或共享Core，也未将未接线候选计入已支持牌池。十二候选在当前data/cards.json母表均不存在。规则来源固定为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；逐文件哈希附后。这里只提炼事实并独立实现，不复制Java代码或游戏资源；未认证官方二进制。

## constructor/use/upgrade事实

| 候选 | 费用/稀有度 | 基础→升级与真实动作顺序 |
| --- | --- | --- |
| Wild Strike 狂野打击 | 1/Common Attack | NORMAL12→17，再将Wound1插入随机draw位置；带STRIKE标签 |
| Reckless Charge 莽撞冲锋 | 0/Uncommon Attack | NORMAL7→10，再将Dazed1插入随机draw位置 |
| Intimidate 威吓 | 0/Uncommon Skill | 每个敌人分别ApplyWeak1→2；消耗；Artifact逐敌独立处理 |
| Immolate 燔祭 | 2/Rare Attack | NORMAL AoE21→28，再将Burn1加入discard；末杀清理可取消未执行的生成尾 |
| Limit Break 突破极限 | 1/Rare Skill | LimitBreakAction检查Strength是否存在，TOP再施加当前有符号值；基础消耗，升级仅取消自身消耗 |
| Sever Soul 灵魂切断 | 2/Uncommon Attack | ExhaustAllNonAttackAction，再已捕获NORMAL16→22；自身无固有消耗 |
| Second Wind 重振精神 | 1/Uncommon Skill | BlockPerNonAttackAction，按卡牌修正后的5→7格挡值，先全耗非攻击牌，再每张各给固定格挡；自身无固有消耗 |
| Fiend Fire 恶魔之焰 | 2/Rare Attack | 动作执行时取剩余手牌N，先随机消耗N张，再对原目标NORMAL7→10共N次；自身另在UseCard消耗 |
| Flame Barrier 火焰屏障 | 2/Uncommon Skill | 普通Block12→16，再获得FlameBarrier4→6；下次玩家回合开始排Remove |
| Evolve 进化 | 1/Uncommon Power | 每抽到Status，且hook当时无NoDraw，BOTTOM排Draw1→2 |
| Fire Breathing 火焰吐息 | 1/Uncommon Power | 每抽到Status或Curse，BOTTOM排null-owner纯THORNS AoE6→10 |
| Blood for Blood 以血还血 | 4→3/Uncommon Attack | NORMAL18→22；每次正HP损失通知当前hand/draw/discard实例updateCost(−1) |

状态牌复用当前数据中兼容的Wound、Dazed、Burn，缺失才追加。Wound为−2费、不可打、无固有消耗/虚无；Dazed为−2费虚无；Burn为−2费，回合末self-owner THORNS2，升级4。Burn可被格挡，并非HP_LOSS；不能用loseHp冒充。复用状态定义类型/费用/空效果/虚无标志不兼容时明确报错；Burn还要求已有burnDamage2/升级4的生命周期元数据。

## 生成牌与随机流

Wild Strike/Reckless Charge复用现有makeTempCard(op,pile='draw',randomSpot=true)，不塞入discard。CardGroup.addToRandomSpot：draw为空直接追加，不抽随机数；非空调用cardRandomRng.random(size−1)，包括size=1时random(0)。使用牌已经移入cardInUse，不能混进抽牌堆计数。伤害先执行，末杀时MakeTempCardInDrawPileAction是会被清除的生成尾。

Immolate的Burn走MakeTempCardInDiscardAction。在末杀时此尾同样可被清掉；不要因为Burn是状态牌就无条件生成到战斗结束后。新状态的onDraw hook仅在真实抽入时触发，生成到hand不等于抽牌。

## 整手消耗的TOP/BOTTOM顺序

Sever Soul遍历hand时，对每张非Attack依次addToTop指定消耗，因此实际按原hand的逆序消耗。Power/Skill/Status/Curse均是非Attack；cardInUse已不在hand候选中。

Second Wind先对候选集合addToTop各个GainBlock，再对同集合addToTop各个ExhaustSpecific，所以执行顺序是**先耗完全部候选，再逐个格挡**。传入的是卡牌this.block，即Dex/Frail已经作用过一次的值；每个GainBlockAction不能再加一遍Dex或再乘Frail。该动作类型是BLOCK，不是GainBlockAction本身；涉及提前战斗结束时不能错误套用GainBlock保留例外。

FiendFireAction先向TOP放N个DamageAction，然后向TOP放N个 `ExhaustAction(1,true,true)`，最后的true为anyNumber。它让所有非空手牌都走random分支，包括最后仅一张时的random(0)，因此N张手牌消耗N次cardRandomRng，不能复用True Grit的单牌无RNG捷径。使用牌自身不计入N，但稍后自身消耗也会正常触发FNP/DE。

每次耗牌仍调用同一个Exhaust dispatcher：哨卫TOP能量可以插在下一张随机消耗之前；FNP/DE的BOTTOM尾则排在已存在的攻击和UseCard之后。Fiend Fire的N次伤害全用原目标和同一NORMAL快照，不能用消耗过程中改变的力量、易伤重新算。未知onExhaust遗物、自身回调继续由Exhaust.plan显式拒绝；不能静默忽略。

## 抽牌、反击与回合hook

Evolve/FireBreathing均默认priority=5，按首次获得顺序保留。onCardDraw只是BOTTOM排动作：一个原始DrawAction请求的牌先抽完，之后才执行其产生的额外抽牌或火焰尾，不能在单张抽牌函数中递归立即兑现。如果FireBreathing先排并杀死最后怪物，尚未执行的Evolve额外抽牌应被清掉；反过来则抽牌先完成。

Evolve只认STATUS且在hook创建时检查NoDraw；FireBreathing认STATUS或CURSE，没有同样的NoDraw hook条件。真正DrawCardAction执行时仍会再次检查NoDraw、满手及空堆。即使已经排入Evolve Draw，随后Battle Trance的NoDraw先生效，也会阻止那个后续Draw。FireBreathing的伤害矩阵在hook时用createDamageMatrix(amount,true)捕获，owner=null、类型THORNS，不受Strength/Weak/Vulnerable等普通攻击修正。

FlameBarrier.onAttacked检查owner非nil、owner不是自身、类型既非THORNS也非HP_LOSS；当前枚举中即NORMAL。**不要求正HP损失**，0伤或完全被Block吸收的每一击也会TOP反击4/6。反击自身为THORNS，不能递归触发另一个Barrier。下一次atStartOfTurn只BOTTOM排RemoveSpecificPowerAction；不是在敌回合末随便清掉。与普通Thorns等多个反击同在时，Core必须把各Power的TOP动作按源Power顺序统一排入，不能固定Barrier先/后。两种Power均未改priority，继承5；先获得的先排TOP，因此实际反伤执行顺序反过来。当前sts-flow通过actor.powerScheduleOrder保留此组获得顺序，并在真实移除Barrier时同步移除记录。

### 逐张抽牌与Void的准确回调位置

固定AbstractPlayer.draw(int)第1614–1637行与无参draw()第1639–1647行的顺序：

1. 从draw顶取c，先调用 `c.triggerWhenDrawn()`；此时还未加入hand。Void在这里向BOTTOM排LoseEnergyAction(1)，没有当场扣能量。
2. hand.addToHand(c)，再drawPile.removeTopCard。
3. 按Power列表顺序调用onCardDraw(c)，因此同张Void的Evolve/FireBreathing尾晚于它自身的扣能量尾。Corruption等无排队的状态修改在各自Power回调位置立即发生。
4. 按遗物持有顺序调用onCardDraw(c)。
5. 无参draw()最后调用onCardDrawOrDiscard：先powers、再relics，再Corruption手牌扫描和hand.applyPowers/glow。

DrawCardAction逐张调用无参player.draw()。整个原Draw请求和原先排好的on-use/UseCard动作仍在新BOTTOM尾之前；不能在单张抽到Void时立刻扣能量，也不能递归立即执行Evolve。若原队列已有[Draw,UseCard]，抽到Void后其新尾为[UseCard,VoidLoseEnergy,Evolve/Fire(获得序)]。BattleTrance的原NoDraw动作也先于这些新回调尾，因此Evolve可在创建时通过NoDraw检查、执行时又被后来的NoDraw取消。

## Blood for Blood：实例费用与受伤计数

AbstractPlayer.damage只在修正后正damageAmount且房间仍COMBAT时调用updateCardsOnDamage，按hand、discard、draw通知tookDamage，并增加damagedThisCombat。一次失去7生命只触发一次，完全格挡、0伤不触发；不限定伤害来源，敌击、自损、毒或Thorns都可能触发。exhaust和cardInUse不在扫描范围。致死伤害仍可通知其他牌并增加计数，不能直接复用“玩家死亡就跳过”的Rupture执行门槛。

`updateCost(-1)`降低战斗基础费用并保留cost与costForTurn的差额，最低0；如果基础已经0则不再改临时费用。普通重置只能清turnCost，不能抹掉已经降低的combatCost。

创建有两条不同语义：

- makeCopy会以当前damagedThisCombat次数降低新牌成本；本模块created(...,'make_copy')明确执行此规则。
- makeStatEquivalentCopy内部虽先makeCopy，随后会把来源实例cost/costForTurn写回，因此最终继承来源实例费用。created(...,'stat_equivalent',sourceInstance)按来源复制，不能一律按全局历史重算。

同场升级也不能只切upgraded标志后由原始cost3覆盖历史：已有cost<4时，source upgradeBaseCost(cost−1)，然后把负base夹到0，且turnCost的差额基于夹值前的原始newBase计算。模块onUpgrade必须在upgraded flag改为true之前调用；之后普通升级定义只负责22伤等显示。没有调用该明确接口的战斗内升级组合不得声称已支持。

## 独立API与Core接点

新增 `abyss_warrior_status_cards`：

- withCards(data)：深拷贝、marker experimentalWarriorStatus，追加十二候选与三种Power；默认牌库不自动改变。
- adaptDefinition(state,instance,copiedDefinition)：只读适配BloodForBlood实例费用，兼容既有combatCost/turnCost；不改catalog。
- prepareEffect(state,effect,target)：SecondWind捕获卡牌Block，FiendFire捕获原目标ID和NORMAL伤害。必须在卡牌效果执行前调用。
- planEffect(state,effect)：limitBreak、exhaustNonAttacks、secondWind、fiendFire返回纯数据 `{top,bottom}`。**本模块top数组为执行顺序**，调用方反序pushTop。外层记录是 `{kind='effect',effect={...}}`；root可与其他模块的raw effect计划兼容，不改变本契约。
- exhaustRandomAny(state,Queue)：真实独立RNG选择并调用Exhaust.move；预检所有候选hook与RNG，单牌仍随机一次，空手无动作。
- applyPower(state,id,value)：调用Actor.applyPower；Evolve/FireBreathing记录statusDrawPowerOrder，叠加不重排。
- onDraw(state,instance,optionalPowerId)：返回BOTTOM计划；不立即抽牌或伤害。省略id时要求活跃能力有完整获取序记录，缺失明确拒绝；指定id时由Core按统一顺序逐Power调用。
- onAttacked(state,owner,damageType)：返回Barrier的TOP反击计划，类型只接受NORMAL/THORNS/HP_LOSS，未知类型拒绝。planHook(state,'flame_barrier','turn_start')返回移除尾。
- onHpLost(state,positiveDamageAmount)：负责一次damagedThisCombat自增和三堆BloodForBlood减费，调用方不得重复自增。它与Rupture的owner条件分开，要求所有真实正HP损失入口通知，并在死亡时仍保留通知事实。
- created(state,instance,'make_copy'|'stat_equivalent',source)与onUpgrade(state,instance)：上述明确费用生命周期。未知复制模式或不兼容来源升级标志拒绝。

新公共ops是gainStatusPower、limitBreak、exhaustNonAttacks、secondWind、fiendFire；内部动作包括exhaustRandomAny、statusFireDamage、flameBarrierDamage、removeStatusPower，以及现有exhaustHand、damage(normalAmount)、block(fixed=true)。gainStatusPower直接走applyPower，不再把它送回planEffect形成空循环。

所有计划都是纯数据，业务函数不进入state。Core仍负责事务、phase/攻击目标预检、是否允许终局尾、原RNG引用恢复、队列拥有权及typed damage owner。新的私有接口不是默认公共效果的无限扩容；未识别的hook、伤害类型、状态复用或复制模式均明确拒绝。

## 实测、接入历史与当前状态

`tests/lua/warrior_status_build.lua`现有29组。先测组件，再通过真实Combat.new/play/damage/endTurn验证；夹具只安排真实创建的实例和合法元数据，不替换生产规则。

接入前在冻结phase3核的私有副本执行：组件9组通过；第10–14组真实WildStrike/RecklessCharge随机插牌、空draw零RNG、Intimidate逐敌Artifact、Immolate的Burn与末杀清尾通过。第15组真实LimitBreak失败于 `unsupported_effect:limitBreak`，整文件exit1。此项保留为接线前历史，不代表当前结果。

单向同步root的sts-flow核心与新helper后，原24组实际复跑通过，覆盖基础/升级、SeverSoul逆序耗牌、SecondWind只计一次修正、FiendFire N次随机与哨卫、FlameBarrier全盾反击/移除、Evolve/FireBreathing获取序决定末杀前后抽牌、BloodForBlood正敌伤与完全格挡不减费。

再新增5组真实队列回归：

- 两种Barrier/Thorns获得序，分别真实打出FlameBarrier和通过Inventory.apply使用液态铜数据效果。实际反伤事件为3→4或4→3，完全格挡也反伤；次回合只移除Barrier的能力记录，Thorns保留。
- 两种Evolve/FireBreathing获得序，使用带真实Void定义的Warcry暂停点检视纯数据队列：原UseCard之后先VoidEnergy，再两种Power尾；暂停时能量仍1。选牌恢复后能量为0，Warcry已经消耗，Fire伤害事件上的手牌数量精确区分额外抽牌在伤害前或后。
- 真实BattleTrance抽Void：仅在真实pushBottom调用之后记录其动作与当时flag，不替换规则/处理器或结果。记录为VoidEnergy→Evolve Draw→Fire，创建时NoDraw=false、能量1；执行时NoDraw已生效，Evolve没有把刚丢弃的BattleTrance洗回，Fire照常造成6纯伤且能量0。

最新定向命令 `node scripts/test-lua.mjs tests/lua/warrior_status_build.lua` 返回 `WARRIOR_STATUS_BUILD_PASS29`，exit0，约1.9秒。模块数据未因这轮复核改变；只更新owned测试和本文。原24组及新增5组均在真实Core中执行，不能以这些离线结果代替整个项目fullsuite或平台/实机验收。

本切片未运行fullsuite、提交、推送、Backlog变更、平台导入或实机验收。phase3冻结输入未被本片修改；root隔离树已接线，本切片的实际验证仅限其私有副本，整体集成与全量检查由root另行执行。

## 固定来源SHA-256

| 固定来源 | SHA-256 |
| --- | --- |
| [actions/common/DrawCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java) | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| [actions/common/ExhaustAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ExhaustAction.java) | `10fd566a420d2549c3705a564ca6274da189eacad7df1872ddf2867af936f510` |
| [actions/common/MakeTempCardInDrawPileAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDrawPileAction.java) | `c00b2da9c82d6e5fed1f638312a2af46dcd586bcd76e963f859e4417629ac2fe` |
| [actions/unique/BlockPerNonAttackAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/BlockPerNonAttackAction.java) | `59cb2ad95b5cbb93a51f466d2d7e6b6faa6ce2b11e35296c63c3ba959796a0a4` |
| [actions/unique/ExhaustAllNonAttackAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/ExhaustAllNonAttackAction.java) | `d3897050ce7c38ec26143de98cc8efca5d138922430858bfb1fd8b3597ad1c07` |
| [actions/unique/FiendFireAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/FiendFireAction.java) | `ce25bf9928fe36732d6a70c69833341f46c57516879efa6e64ff5b23dcda1c4d` |
| [actions/unique/LimitBreakAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/LimitBreakAction.java) | `98cb15dc0512cfa3be3db2de1b6e4de762a61c8815b2b5d8047d5c482a8aa509` |
| [actions/unique/LoseEnergyAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/LoseEnergyAction.java) | `c9e2e5b9516fda59b6caf662d72cbf12edac26bea24c49e780f46275ad468820` |
| [cards/AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [cards/CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [cards/red/BloodForBlood.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/BloodForBlood.java) | `7ab2b9f9422769e8e8afb54c765ea22a6c68114f8df7ded5e9de660d64d13de0` |
| [cards/red/Evolve.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Evolve.java) | `d05ceaa342fa51772c5b61ee0d92f7a78a5748a74d4132113e325512d8fc4a32` |
| [cards/red/FiendFire.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/FiendFire.java) | `393188b5f5027c4909eab173ba000f59df2d24e2b62e5a3e081967aa0a16e9e5` |
| [cards/red/FireBreathing.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/FireBreathing.java) | `57358448ed6c10f9889fb130ff0c42958bc550671ce70fc1bf2f472ab0bdddbe` |
| [cards/red/FlameBarrier.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/FlameBarrier.java) | `6a0edc533817f5a3fdcb473b189268b6124389ebd357880b85b7f08187ec5da8` |
| [cards/red/Immolate.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Immolate.java) | `9356514ed05438b1f73faf08c8f6646562b809b8069896de124951ebea4dc9f3` |
| [cards/red/Intimidate.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Intimidate.java) | `9a01dbcdb3dff372de48df7af83214b831459be6e9c75697a0c4c63761e0877c` |
| [cards/red/LimitBreak.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/LimitBreak.java) | `6e406d2b9479220cc2ccb9f85c7b767503a353c0760effa383313b537e0f741c` |
| [cards/red/RecklessCharge.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/RecklessCharge.java) | `9d1e9b7fd9d0c3ed36ff6b3f4494a2c8d6900a1e39816bffe3a45fc2cc868a10` |
| [cards/red/SecondWind.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/SecondWind.java) | `91c7bb8182c0084d335ca913d3eb099ecb7f8a37e0dc82646d84885e202cbb8d` |
| [cards/red/SeverSoul.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/SeverSoul.java) | `5923e70f4c32a43cd3be7e51bd7ef099c417b0e47b46c777df8c9042f9ab97a9` |
| [cards/red/WildStrike.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/WildStrike.java) | `769565c20247e73c5a85bb19edc68abf18c77e4b5d918b687a173d4917da1c9e` |
| [cards/status/Burn.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/status/Burn.java) | `a065c155ce2efb9b7a968bfe55e68d5290d02ddabcf6becd4ca43db80a30dc12` |
| [cards/status/VoidCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/status/VoidCard.java) | `653163beb2f36e1d48e178a87f6b5aa283adff67d957ef4f779bd3b389041e03` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [powers/AbstractPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java) | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| [powers/EvolvePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/EvolvePower.java) | `60f0892f3a7429f885be6ca8d3cb79ab4aaa2b7ee89d922a4c9df8a7c27ee629` |
| [powers/FireBreathingPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/FireBreathingPower.java) | `0e9d674c928473fdb7464dac67f78fba279294fc20e79f729f93d0d2139e4d58` |
| [powers/FlameBarrierPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/FlameBarrierPower.java) | `2d428558a399d7bde4026092db001037a5bc73748fed25f9d4db40ef39e684bd` |
| [powers/StrengthPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/StrengthPower.java) | `20b05040efe9d6ad693dd763a658c86df9db1b1ac365351c4c8d81c7f6ca08c9` |
| [powers/ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | `78ce7c63874a3539f03c50a9cdfdf8bcfba7b47e73bce18c10672e5bad3ae87a` |
