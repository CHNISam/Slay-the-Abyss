# 238张冻结树的回合与暂停续行独立复审

## 本次结果

只读 `/workspace/sts-flow` 当前238张冻结输入，使用私树 `tests/lua/phase_four_turn_review.lua` 调用其真实 Core。未改该树任何源或测试，未执行全量、提交或Backlog操作。没有替换 Actor、Combat、Queue 或 family 业务函数。

实际输出：`PHASE_FOUR_TURN_REVIEW_PASS 4 FAIL 1`。红例是无姿态功能的合法 Silent Core 入口在手选弃牌前执行 Sharp Hide；开启普通Run所用Neutral姿态选项的同输入对照通过。其余三个 Weave/Scry 暂停续行边界通过。**不将该红例扩大为所有正常 Run 都发生同样问题**：目前 Run 为实验职业传 enableStances=true，恰好把这条入口推入了正确的队列路径。

前轮已修的 Divinity开回合退出/Flurry回手顺序、Choke/SharpHide获得序不在本轮重复报告；Buffer与Tools等未接入Profile的最终候选也不作为238张的现有缺陷或覆盖计数。

## 确认缺陷：手选弃牌是否排队依赖了无关功能选项

最小输入是：

- `Combat.new(Profiles.prepare(Data,'silent'), {seed=42, cardRandomSeed='42', deck={'dagger_throw','tactician','defend_green'}, enemies={'cultist'}})`，不启用Silent不需要的姿态功能。
- 仅用受控Core状态边界将玩家HP设为3、敌人HP设为100，并通过真实 Actor.applyPower 给敌人Sharp Hide 3；三张牌都由Combat.new创建，未注入新牌或替换UID。
- 真实play Dagger Throw。剩余两张手牌使DiscardAction需要手选；原生抽牌因两堆为空直接结束。

固定源预期：Dagger Throw原生伤害9先结算，然后暂停于弃1张；玩家仍3HP、energy2，原Dagger Throw仍是using card。选择Tactician后，它的TOP能量先变为3，后续Sharp Hide才杀死玩家；UseCard清理未到达，Dagger Throw仍保留using身份。

冻结实现实际：返回时已是0HP/defeat，仍有未完成的pendingDiscard，玩家根本未选Tactician。失败断言为 `manual discard must pause before onUse Sharp Hide: 0 ~= 3`。

原因是 `Effects.requiresQueue` 不把requestDiscard自身当作需队列的效果；`Combat.play` 仅可能被stance、Void/Evolve、其他触发等条件间接推到beginQueuedPlay。此输入进入旧resolvePlay：原生effects留出pendingDiscard后，代码继续执行EnemyAI.afterCard与清理。队列是否正确与是否启用一个不相干的姿态功能绑定。

精确源证据：

- [DaggerThrow.java:29–35](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/DaggerThrow.java#L29-L35)：BOT排Damage、Draw1、非随机Discard1。
- [AbstractPlayer.useCard:1351–1356](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1351-L1356)：card.use先构造原生动作，再构造并加入UseCardAction，随后移出手牌。
- [UseCardAction:57–60](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java#L57-L60) 调怪物onUseCard；[SharpHidePower:39–42](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/SharpHidePower.java#L39-L42) 再BOT排反伤。因此反伤位于尚未完成的原生DiscardAction之后。
- [DiscardAction:68–90](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAction.java#L68-L90) 的非随机路径打开选择并等待，选中牌移入弃牌后调用manual hook；[Tactician:34–35](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Tactician.java#L34-L35) 将GainEnergyAction排TOP。

建议修复点是让requestDiscard的队列要求直接由效果决定，完整暂停、选择、续行与using-card生命周期不能依赖stance或其他Power是否恰好存在。本次仅提供红例，没有修改runtime。该修复应在新集成树完成，不能悄悄修改正在全量核查的冻结树或把旧全量结果自动继承给新输入。

## 实际通过的四个边界

| 用例 | 实际验证 |
| --- | --- |
| 相同Dagger Throw启用Neutral姿态选项 | 先暂停且仍3HP；选择Tactician使能量TOP变3，再Sharp Hide致死；原using UID不被提前丢弃。这一对照限定了缺陷入口。 |
| Cut Through Fate＋满手边界＋弃牌中的Weave | 原生伤害只执行一次；Scry暂停时不提前抽牌/获得Nirvana Block；继续后原生Draw填满手牌，UseCard清理，然后Nirvana固定Block3，Weave尾部因满手留在弃牌。 |
| 上述输入加NoDraw | 原生Draw受阻，但Scry/Nirvana仍运行；空出的一手位置允许后置Weave回手，牌堆没有被原生Draw消费。 |
| Scry选择抽牌堆中的Weave | 无效UID拒绝保持同一个pending对象、队列引用、敌人HP、energy和事件长度；合法选择后只续行一次、不重放原生伤害；随后Draw填满手牌，晚到的Weave回手因满手被阻止；旧token重放不再执行。 |

源码 [ScryAction:37–65](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/ScryAction.java#L37-L65) 先调Power.onScry，非空抽牌堆才继续卡回调；选牌搬到discard后再次遍历discard。`Weave.triggerOnScry`（33–34）BOT排DiscardToHand，而不是立即回手。测试检查真实事件帧中Nirvana早于回手、using-card先被清理，未将组件返回的计划数组当作真实Core通过。

## Tools未来接线约束，不计作当前缺陷

固定源 [ToolsOfTheTradePower:36–39](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ToolsOfTheTradePower.java#L36-L39) 在post-draw排Draw(amount)与非随机Discard(amount)。真正手选会暂停回合队列；它不属于任何正在使用的卡，不应伪造pendingPlay/cardInUse来借用卡牌结束流程。

当前238的startPlayerTurn要求Queue.run返回true；activeQueue下chooseDiscard还要求pendingPlay。因此未来接Tools至少需要明确的回合continuation owner、返回pause的合法路径、选择后的同队列resume，以及只完成当前回合尾部一次的收尾，不能重放敌人回合、pre或普通Draw。Run层的药水/结束回合/其他选择门槛和UI代次也要覆盖这种无pendingPlay的回合选择。这里没有向238输入伪造Tools status写一个“未支持失败”来冒充新缺陷，也没有对尚未接线的未来接口宣称已通过。

## 重现命令与输入指纹

```sh
cd /workspace/sts-flow
node_modules/.bin/fengari /workspace/sts-natural/tests/lua/phase_four_turn_review.lua
```

Fengari CLI在这套环境中即使Lua抛错也可能返回shell exit0；应读取最终PASS/FAIL标记与Lua错误，不能据进程0退出声称本审查全绿。本次只有这五个定向用例，没有运行测试聚合。

| 冻结输入文件 | SHA-256 |
| --- | --- |
| src/lua/abyss_combat.lua | `80a987e38c146ad673eb8683caa22968ad55da653a81e538450e65832e49c552` |
| src/lua/abyss_effects.lua | `7d0b9d422062c6234055c30ef5161ed95b48eec446848904ff8396ea12863db3` |
| src/lua/abyss_discard.lua | `e1bec2599adf33896cc457f6e1ab62b6386a350d652fc3d7515db3aaec2235d4` |
| src/lua/abyss_scry.lua | `07d9a86bc13c145069cd5bed0a2aaf1bcd45e05a3a37e2627a41ef16337618e9` |
| src/lua/abyss_watcher_flow_cards.lua | `e8d0785239150c1ca364fc2f9901ba2c2cda0ead31fb709ea713a71979dd1c82` |
| src/lua/abyss_turn_powers.lua | `e5c7183a772693629a7b132befd08c21d1703e5b5e24757c6f74bfe060d58c61` |
| src/lua/abyss_character_profiles.lua | `e56bc38a5ee32154516c2e755064f0591f7c8da6a902a914d29362064205348b` |

固定社区反编译来源commit为 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`，未认证官方JAR；以下源hash来自已固定本地归档，不是原版客户端实测：

| 源文件 | SHA-256 |
| --- | --- |
| cards/green/DaggerThrow.java | `0ca70937cccdc12ef9ee1af73d3ad0571d998edd003d46a2001e864973cb34d4` |
| cards/green/Tactician.java | `d6dfa45bcddc58ebbab63b37018c9a4f0fe8edce76d40197168640d10176bbe6` |
| powers/SharpHidePower.java | `a7cf449a907ca34569059aca1310619deb597d32cdd84201815d024614ff576a` |
| actions/common/DiscardAction.java | `8c711be291822386b64fe0a6c9bc55b920b7a09122fb55f09184b6ca96063c10` |
| characters/AbstractPlayer.java | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| actions/utility/UseCardAction.java | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| actions/utility/ScryAction.java | `a22d8875a9ac3a4b6c445abad65a6ca4defa8fb309d1f6a6e51506a8e3b55147` |
| cards/purple/Weave.java | `c6019a97a8eada05b2246be97b0103e1a4ead3ae6fc5c26ce8b555a955c6f42c` |
| powers/ToolsOfTheTradePower.java | `f58c2e284e1113c4e1f1e45903b23109347a4f6c080bb98e2af0554e007b2dde` |
