# Accuracy 与 Shiv 基础伤害切片

本执行者的切片只有 `abyss_shivs.lua`、独立测试和本文档。共享Accuracy钩子由主线程另行接入，本轮测试已同步该真实实现；本执行者未修改共享Combat、Effects或原Silent生成器。Infinite Blades保留独立opt-in数据接口，现由显式实验Profile注册；旧Silent基础helper保持原范围。不代表完整小刀流或实机通过。

## 固定来源

公开社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，声明V2.3.4 / 2022-12-18；未经正版PC二进制认证。下列SHA256为本轮HTTPS只读抓取完整原文件字节所得，未保存原方法体：

| 路径 | SHA256 |
| --- | --- |
| cards/green/Accuracy.java | `5f05bd7877699a6aa1ecd81f91d7bb84ef4055dbc51fdf9ef75c935307e3d124` |
| powers/AccuracyPower.java | `f55d9cb1454c77625abb611fb72518e5136eeb4c198613c570f81cf553ced352` |
| cards/tempCards/Shiv.java | `904b5519577bdc1ee3c5af418f4f5db22c3053a1e450bb4888363b7ec6c29767` |

Accuracy为1费罕见能力，基本4层，升级6层。新Shiv构造时读取当时Accuracy；基础伤害4，加当时能力层数；升级Shiv再增加2。AccuracyPower构造和叠加会把手牌、抽牌堆、弃牌堆、消耗堆内所有Shiv的基础伤害**重设**为4或6加当前总层数；不是再加一次旧bonus。其onDrawOrDiscard只刷新手牌。

AccuracyPower没有onRemove覆盖。因此卸除能力不会自动把已改过的Shiv恢复成4/6；已有实例保留之前基础伤害，新构造实例才不再带Accuracy。不能在每次读牌时简单加当前status，否则会错误撤销旧实例的基础伤害。另一份Accuracy重新生效时则按新总层数覆盖所有旧实例。

能力层数变化和实例基础伤害是不同的生命周期：例如ReducePower修改层数本身不等于Accuracy的stackPower刷新；此后onDrawOrDiscard刷新手牌，但其他牌堆保持旧基础，直到后续明确刷新。本文只提供所需钩子，不声称所有移除/减层来源或特殊复制路径已接入。

## 最小共享契约

- `withCardDefinitions(data)` 返回数据副本，只追加Accuracy卡牌及buff/intensity/none状态；不含Silent牌组、自然卡池或生成器。
- `applyAccuracy(state,4或6)` 通过真实Actor施加并刷新四堆实例，保持该次状态事件frame与新实例基础一致。
- `created(state,instance)` 在**真正构造新的Shiv实例**时调用，记录其创建时的 `shivAccuracyBonus`；升级基础由实例upgraded标志加2。已有副本的stat-equivalent-copy须保留原实例字段，不能一律用当前能力覆盖复制来的旧基础。
- `onApplied(state)` 是共享ApplyPower适配器已完成施加后的四堆刷新钩子；不得与applyAccuracy重复施加状态。
- `onDrawOrDiscard(state)` 由共享抽牌/弃牌生命周期调用，仅在Accuracy仍存在时刷新手牌，不累计。
- `removeAccuracy(state)` 提供当前有限显式卸除动作，清能力但保留实例字段。实际其他RemovePower来源仍需对应共享分发。
- `adaptDefinition(state,instance,detachedCard)` 在共享cardDefinition应用升级后、应用通用damageBonus前调用；只把Shiv伤害基础设为4/6加保存的bonus，不改目录。随后Strength、Weak、Vulnerable及姿态倍率全部交给现有Actor。

例如基础Shiv：4基础+4Accuracy+1通用实例bonus+3力量，再乘Weak .75、易伤1.5和Wrath2，结果27；Accuracy不是最后乘完后另加，也不能在定义和伤害两处重复加。

共享出牌事务必须保存四个牌堆中**每张实例对象**的新字段并在失败时原引用回滚，不能只保存牌堆数组或被打出的那一张。这里没有建立另一套战斗事务。

## 已验证与集成限制

`node scripts/test-lua.mjs tests/lua/silent_shivs.lua`通过25组。Accuracy部分使用真实Combat.play、真实cardDefinition和真实Blade Dance生成器，没有注入机制适配器；覆盖四堆刷新、重复读取不叠加、移除后旧/新实例差异、升级实例、力量/虚弱/易伤/Wrath顺序、目录不变及输入预检，还覆盖Accuracy后Blade Dance生成三张各8伤害的小刀。

测试中唯一临时函数替换是故障注入：真实Accuracy效果完成并已经刷新四堆后故意抛错，验证共享出牌事务恢复原四堆数组、每张原实例字段、能力状态、事件和能量；随后恢复原函数并重试成功。它不提供任何缺失机制的模拟适配。升级边界仍是明确夹具，不宣称已实现游戏内临时小刀升级操作。

当前同步的共享生成器已删除Accuracy非零限制并调用created，Master Reality仍保持未支持保护。Storm of Steel及其弃牌连锁没有在本片实现；不能据Accuracy宣称所有小刀组合完成。

能力及实例bonus仅支持非负安全32位范围，预留最大基础6；超界明确拒绝，不模拟未经取证的Java整数溢出。

## Infinite Blades／无限刀刃

这里采用常见简中卡名“无限刀刃”，不是技能Blade Dance的“刀刃之舞”；固定方法链提供英文卡ID，本文不声称该社区源码含官方中文本地化认证。

固定提交新增读取：

| 路径 | SHA256 |
| --- | --- |
| cards/green/InfiniteBlades.java | `94c99d3332efcd8e570afcb31ca8408e9e604e7588baa1d34f0c33fb323baa87` |
| powers/InfiniteBladesPower.java | `44c1d371d62143fc1da3f88cbf59f9c8f0a7461372f5c0a3f2c96d3e70165e9c` |

1费罕见能力，每次获得1层；打出时不立即生成小刀。升级仅获得Innate，不提升每层生成数量或降低费用。持有多层时每个玩家回合开始生成等于层数的基本Shiv。`InfiniteBladesPower.atStartOfTurn`把 `MakeTempCardInHandAction(new Shiv(),amount,false)`加入BOT；`core/AbstractCreature.applyStartOfTurnPowers`分发此钩子。`actions/GameActionManager.java`第331–350行先调用起始powers，再把普通DrawCardAction入BOT，所以生成在常规抽牌前。新小刀会占据抽牌前的手牌空间，满手生成的部分进入弃牌堆。

### 独立接口

- `withInfiniteBladesDefinition(data)` 单独opt-in追加卡及能力状态。它不被普通withCardDefinitions调用，以免Innate/回合钩子尚未共享接好就进入奖励池。升级具有innate元数据；当前共享Opening入口已接入，基本/升级真实首次抽牌对比也已验证。
- `applyInfiniteBlades(state,1)` 只获得能力，不触发生成。
- `startTurn(state,generateFn)` 在共享玩家回合起始能力位置调用，早于普通抽牌；generateFn应是共享 `Silent.generateShivs`，仅通过当前调用栈传入，不存储函数到state。
- 回调生成基本Shiv，返回每张UID；本模块验证新身份、数量和牌堆归属，并以本次源构造时Accuracy层数stamp。手牌/弃牌堆两种去向均保留。生成事件中的原有牌堆数量和顺序保持，更新其小刀字段而不把所有中间frame替换成最终frame。

早期组件测试保留显式hook harness。当前新增真实Combat.endTurn链路：基本和升级能力打出不立即生成，下次玩家回合先生成一张再普通抽牌，下一回合再创建新UID；还通过固定seed1验证基本牌不会被强制抽入起手，而升级Innate会在相同洗牌熵后进入首手。真实Accuracy+Infinite Blades跨完整回合产生8伤害Shiv。旧组件检查与这4个真实共享入口检查合计25组，均通过，未使用机制mock。

### root精确接入清单

1. 保留真实Accuracy接入：升级后adaptDefinition再加通用damageBonus；gainStatus accuracy调用applyAccuracy；新Shiv created；抽弃时onDrawOrDiscard；事务深存四堆每张实例。
2. 在普通玩家回合起始能力队列位置、常规抽牌入队前调用Infinite Blades hook，保留与其他起始powers的持有/priority顺序。Noxious Fumes仍在post-draw，不能放在同一时点。打Power时只获得层数，不调用hook。
3. 在当前调用栈传共享生成器，仍使用生成器的UID、手牌10张容量、溢出弃牌、Accuracy创建stamp和Master Reality未支持保护。整体起始回合事务负责生成/回调失败的原引用恢复。
4. Opening规则依据源 `cards/CardGroup.java` 第911–936行：先按shuffleRng洗完整副本，再收集Innate/瓶中牌并按源列表顺序置顶；超过masterHandSize的额外起手抽牌还有独立preTurnAction。不能只强塞起手牌、取消洗牌或只改drawPerTurn。这一规则由共享Opening另行实现，不在Shivs模块中重复实现；本片验证其基本/升级实际首手表现。
5. 当前共享钩子、Opening及Profile-only注册已接好，上述基本/升级首次开局、跨回合和Accuracy组合回归通过。旧Silent helper不自动扩大范围，只有实验Profile明确调用withInfiniteBladesDefinition。超起手数量等通用Opening边界由其独立测试负责，不能以本片4个入口测试冒充全部Opening验收。保留来源等级、受限卡池及非实机的报告边界。

Infinite Blades没有任意10层限制；模块允许非负安全32位层数，实际生成须通过共享UID空间预检，手牌最多10张，其余进入弃牌。11层实测生成11张，10张手牌和1张弃牌，每个实例带Accuracy4并有8基础伤害。Accuracy数值仍保留其基础伤害安全范围，不能把它的预留上限误用为IB层数上限。没有支持Master Reality、全部起始powers组合或Storm of Steel。


## 历史24张常规绿牌Profile的自然毒流冒烟

此处是独立自然毒流测试的基线更新记录，不是IB已经自然获取并使用的证据。旧 `/workspace/sts-next` seed11及Accuracy-only `/workspace/sts-ui` seed1均保留为冻结历史。最终Profile追加三张弃牌卡及Infinite Blades后，旧seed1不再提供原记录的奖励；没有改掉落算法或数值去维持旧断言。

`tests/lua/silent_natural_build.lua`使用新固定seed65，前四个真实普通房：jaw_solo生命70→70、louse_pair70→70、small_slimes70→70、louse_trio70→63。按自然奖励命令依次领取Noxious Fumes、Bouncing Flask、Deadly Poison、Dagger Throw。永久牌组12→16，实际Fumes施放3次并观察7个后续post-draw，Flask3次逐次3跳独立RNG及独立施毒，Deadly Poison1次。没有注入生命、能量或牌，只用明确的房间入口harness在领取后推进floor。

最终Profile实查为20张非基础绿色奖励牌，加4张基础绿牌，共24张常规绿牌；Shiv单列special，不能把24全部写成奖励池规模。这仍是应用受限均匀池，不宣称原版PC种子、概率、Map导航或客户端验收。


## 历史41张常规绿牌Profile的自然毒流与重建

当前Profile继续加入14张攻击/防御牌及三张真实on-use能力后，达到37张非基础绿色奖励牌加4张基础绿牌，共41张常规绿牌；不含special小刀，不代表完整Silent原版牌池。旧seed65在新池上已经实际失败于其奖励断言，保留为上一冻结基线的历史，不能把旧轨迹重新解释为当前结果。

本轮有界检查seed1–56，没有更改奖励算法、随机流或数值，找到新固定seed56。`tests/lua/silent_natural_build.lua`实际轨迹：

| 普通房入口 | 回合数 | 实际生命 | 实际三选一奖励 | 正常领取 |
| --- | --- | --- | --- | --- |
| louse_pair | 5 | 70→70 | Grand Finale / Noxious Fumes / Deadly Poison | Noxious Fumes |
| small_slimes | 5 | 70→68 | Deadly Poison / Noxious Fumes / Reflex | Deadly Poison |
| cultist_solo | 4 | 68→68 | Caltrops / Heel Hook / Tactician | Caltrops |
| wildlife | 5 | 68→50 | Bouncing Flask / Grand Finale / Deadly Poison | Bouncing Flask |

真实Silent以70/70生命、12张初始卡和唯一初始蛇戒开局，永久牌组经真实领奖命令由12→16。后续三场真实打出Fumes3次，观察到10个后续玩家回合post-draw施毒；Deadly Poison实际打出4次并逐次断言新增5毒。这里证明Fumes+Deadly Poison的自然构筑；Caltrops和Flask虽经真实奖励得到，本条没有声称已经使用。没有往牌组塞牌或改写HP/能量，只有声明过的房间入口harness在领奖后递增floor，因此不认证地图路线导航、原版掉落概率或平台/客户端UI。

所有房间ID、精确生命前后、回合数、三张奖励及实际加入永久牌组均有固定断言；胜利后不得留下未决动作队列或选牌。随后以同seed重新Run.new并通过同一实际命令策略完整重放四场，比较纯数据manifest：角色资源、永久牌及UID、遗物/药水、房间账本、真实施牌计数、遭遇快照、最后战斗的演员状态、四个牌堆及UID、剩余队列/选择状态，以及run与最后combat的全部已保存随机流快照。此处是从种子和命令重建的确定性回归，**不是实现了外部存档恢复API**。

当前自然用例为一条固定四房轨迹，包含独立重建重放；退出码0，不把重放两次写成两条不同自然构筑验收。


## 当前61张常规绿牌Profile的自然毒性追击构筑

Tactics20张进入Profile后，常规绿牌为61张（57张非基础奖励牌+4张基础），special小刀另计；最后14张候选尚未启用。旧41池seed56已经在61池实际失败于第二房奖励选择断言，因此保留上节为冻结历史，不篡改旧轨迹。

本轮仍只在seed1–64范围内查找。原限定Fumes再获另一毒牌的策略查1–32与33–64均未找到四战结果，用时15518ms+16711ms。只调整读取手牌/敌人状态的出牌策略与真实奖励选择策略，允许不同毒牌组合，并将新支持的Crippling Poison纳入合理候选；没有改写奖励、RNG、牌组、生命、能量或敌人数值。在同一范围内从1重查，至9即找到可用路线，用时9299ms；不扩大为无界扫描，也不以扫描推算原版概率。

`tests/lua/silent_natural_build.lua`当前固定seed9：

| 普通房入口 | 回合数 | 实际生命 | 实际三选一奖励 | 正常领取 |
| --- | --- | --- | --- | --- |
| jaw_solo | 8 | 70→69 | Sucker Punch / Leg Sweep / Poisoned Stab | Poisoned Stab |
| small_slimes | 3 | 69→69 | Finisher / Prepared / Flying Knee | Finisher |
| cultist_solo | 3 | 69→69 | Reflex / Skewer / Bane | Bane |
| blue_slaver_solo | 4 | 69→62 | Storm of Steel / Escape Plan / Accuracy | Storm of Steel |

真实开局明确断言70/70生命、原12张未升级牌（5Strike、5Defend、Neutralize、Survivor）、唯一Ring of the Snake、无初始药水。每战从Run.startRoomCombat进入，Run.play/chooseDiscard/endTurn执行，胜利后通过claimCardReward/claimGoldReward/leaveCombatRewards领取；永久牌组12→16、4胜、生命62。只有领奖完成后harness递增floor，仍**不是完整Map导航、PC掉落概率或平台客户端UI验收**。

Poisoned Stab在房2第2回合、房3第1/3回合、房4第1回合各真实打出一次，每次独立观察恰好1个+3中毒事件。Bane在房4第3回合命中已有1毒的目标，真实产生2个普通伤害事件，总伤害10（实际回合修饰后的结果），不是把基础两段7强行当成实际伤害。Finisher虽在第二次奖励取得，策略没有使用；Storm of Steel是第四战后奖励，没有声称已经打过。当前自然证据是Poisoned Stab→有毒Bane的实用连动，不复用旧Fumes/Flask计数冒充本轨迹。

测试继续保留精确房间ID、HP前后、回合数、全部三张候选、选择加入永久牌组、奖励完成以及无未决队列/选择的断言。固定seed9随后独立Run.new并完整重放四战，比较原先的资源/牌组/Actor/piles/全部已保存RNG/遭遇状态签名；补纳nextSourceUid、卡牌历史、自动队列与新增选择/保留状态（若存在）。该验证是相同seed与实际命令的确定性重建，不声称实现外部存档restore API。

最终定向用例包含两次独立四战回放，仅计1个自然构筑用例；最后一次exit0。无共享文件改动、无全量套件、无提交或推送。
