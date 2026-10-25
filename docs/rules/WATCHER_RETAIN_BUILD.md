# 观者保留成长：四张牌的独立切片

交付仅`abyss_retained_cards.lua`、`tests/lua/watcher_retain_build.lua`和本说明。共享Combat/Effects/Run、已冻结验证树和Backlog均未修改；没有提交、推送或全量检查。

## 固定来源

统一使用社区反编译镜像[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。核实语义后独立写实现，不复制Java方法体；镜像不是官方开源或本轮正版二进制/运行认证。

| 文件 | 原始字节SHA256 |
| --- | --- |
| cards/purple/Protect.java | 98c8a3773aa417d96068dd88339299dc951c4dd29bfd8ecd98a78188d76d9d11 |
| cards/purple/Perseverance.java | 696f659509cb18cd78583b05e8954d2125066df2a197699376956cbcb18856a7 |
| cards/purple/WindmillStrike.java | 5974bedbaa5b6f883e28b0f2bb004797bfd7a481f95e14eb1f0304beae3823bc |
| cards/purple/SandsOfTime.java | 5c09eb29b209ea906853424d226423772c2e4251fab25fb39d52f799022d2419 |
| actions/common/DiscardAtEndOfTurnAction.java | d80e3ae091de4bc4e74879f195b5ec2d1bb7e7c7e92eac636bf452d61e4bebf0 |
| actions/unique/RestoreRetainedCardsAction.java | 8bed1c15e51dac6ce10baf7cfd50a51220552274f620adeb8eeef5e7667e3adc |
| actions/common/ReduceCostAction.java | 3d84b5855ff5358938888db1a798fdf6ceef960f18939e7bd53ff256a8c76b5c |
| cards/AbstractCard.java | bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61 |
| powers/watcher/EstablishmentPower.java | 35765432dda3b2a217b13fa28f1a68162086decbdf4af51edf9f5ac7d211feb5 |
| rooms/AbstractRoom.java | 020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05 |
| actions/GameActionManager.java | a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3 |
| characters/AbstractPlayer.java | 2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95 |
| powers/CorruptionPower.java | d1aa54c286ac8b9a02a467abe5bd7aac3dfa7c831c77b4872607316f220f067b |
| powers/DarkEmbracePower.java | 4b6292679fe2980af63124e0d8e86c63b311bedb380f4d47619c92c1aab1bc3c |

## 牌与升级

中文名称用于本项目展示，规则描述由本项目独立编写；固定Java源只通过CardStrings读取译名，本轮未取得其原始中文语言包，不宣称已认证官方译名。

| ID／中文展示名 | 基础 | 升级 |
| --- | --- | --- |
| protect／护身 | 2费技能，保留，12格挡 | 16格挡，费用不变 |
| perseverance／坚韧 | 1费技能，保留，5格挡，每次保留增加2格挡 | 基础7格挡，今后的每次保留增加3 |
| windmill_strike／风车打击 | 2费攻击，保留，7伤害，每次保留增加4伤害 | 基础10伤害，今后的每次保留增加5 |
| sands_of_time／化沙 | 4费攻击，保留，20伤害，每次保留队尾降低费用1，最低0 | 26伤害，费用与降低规则不变 |

风车打击固定源有STRIKE标签，此模块以sourceTags记录，不新增所有打击相关遗物/卡牌机制。升级调用对当前baseBlock/baseDamage再加固定+2/+3，不倒算过去成长。例如未升级坚韧先保留一次为7，随后升级为9，再保留为12；风车先保留为11，再升级为14，再保留为19。不能以“保留次数乘现在的升级成长率”替代历史增量。

## 源动作阶段

AbstractRoom.endTurn先调用玩家end-turn能力钩子，将相应动作排入普通队列，然后排ClearCardQueue、DiscardAtEndOfTurn及后续匿名动作。DiscardAtEndOfTurn先将retain/selfRetain牌移入limbo，再把RestoreRetainedCards置于TOP；普通弃牌和剩余手牌的ethereal动作随后也放TOP，所以它们先于Restore执行。

Restore逐张执行onRetained，再把牌放回hand并清临时retain。坚韧/风车在这一刻直接增加自身base值；化沙仅队尾排ReduceCostAction，不能在onRetained内部先执行。原队列还保留的匿名动作随后把EndTurn/Wait/MonsterStart追加到化沙降费之后；因此化沙降费和全部Restore仍在敌人动作之前，绝不是下个自身回合开始才成长。

普通虚无消耗触发Dark Embrace时，其Draw也是BOTTOM，不会越过已经排在前面的Restore。典型顺序为Ethereal Exhaust→Restore（成长、返回手牌）→DE尾抽→化沙ReduceCost→敌人动作；有弃牌/其他尾动作时继续按实际入队顺序排列。不能为了测试方便把DE改为TOP，也没有据此声称已复现保留恢复超过10手牌。源Restore自身确实没有10上限，但当前支持组合的普通DE尾抽是在恢复之后才按10限制停止。

源end-turn能力动作通常先于Restore，若它们已造成死亡，不能再发保留成长。宿主目前Actor.endTurn混有多种职责，接入时须按这些职责定位，不能用移动整个合成函数来冒充完整源动作队列。

**保留＋虚无复合**存在重要源差异：源先把selfRetain牌移limbo，再遍历剩余手牌的ethereal，可能让同时具有两标记的牌逃过虚无；当前共享旧生命周期优先虚无。本模块对尚在保留阶段的此组合显式拒绝`unsupported_currentcompound`，不猜测或宣称已一致。已经进入exhaust的牌不会成长。

## 接口与实例字段

- `withCards(data)`追加四定义并返回独立拷贝，不改原数据或职业获取池；重复追加拒绝。
- `adaptDefinition(state,instance,card)`在宿主已合并upgrade、尚未应用通用费用覆盖时调用。返回独立定义，叠加retainedBlockBonus/retainedDamageBonus。化沙给出基础4减历史降低的后备cost，通用combatCost/turnCost必须最后覆盖，不能再次从覆盖值里重复减历史。
- `onRetained(state,instance)`只接受仍在hand或宿主显式retainedCards(limbo)的真实实例；已在draw/discard/exhaust或cardInUse中者不成长，死亡或非玩家保留阶段也不成长。保留回调每turn只执行一次，以retainedTurn记录。
- 坚韧、风车分别把本次有效成长量累加到retainedBlockBonus、retainedDamageBonus；不使用仅记录次数的推算。
- 化沙回调返回`true,{op='reduceRetainedCost',uid=...}`，不立刻改费。宿主应在源BOTTOM位置消费，调用`reduceBaseCost(state,instance)`。
- `reduceBaseCost`按固定源modifyCostForCombat(-1)读取当前费用：若turnCost>0，新的combatCost和turnCost都取max(turnCost-1,0)；否则combatCost取max(baseCost-1,0)，turnCost保持0。缺省combatCost用4减既有retainedCostReduction。不是无视当前费用、永远使用4减次数。

retainedCostReduction记录实际发生的降低次数，到两个当前费用都为0后不再增加；它不是所有外部费用效果的总净差。通用combatCost/turnCost保留最终源费用，尤其临时费用与基础费用不同的情况。非法值、溢出、未识别的costForTurn/freeToPlayOnce等旧ABI字段显式拒绝。

## 明确范围与防护

- Protect/Perseverance已与共享Corruption实例费用和使用消耗协议组合验证，因此不再对这两张技能添加多余的Corruption拒绝。成长只改基础格挡，不重置或重复施加combatCost/turnCost。两张攻击不受Corruption影响。此支持依赖宿主已经接通构造扫描、抽牌Power→手牌hook、三堆回合末费用重置，以及UseCard构造时捕获消耗；单独导入本组件不提供腐化引擎。
- Restore只执行hand.addToTop，没有onCardDrawOrDiscard。若保留后手牌已满10，下一正常Draw也不触发手牌hook，某些后构造的新技能可以显示Protect费用2。固定源hasEnoughEnergy仍要求至少2能量，只有useCard跳过实际支付：1能量拒绝、2能量可使用但不扣费并消耗。不能把“零支付”偷换成无能量门槛，或在恢复阶段虚构一个手牌hook强制把显示费用归零。
- Establishment改变保留费用的完整队列交互未实现，存在该能力时拒绝`unsupported_retained_establishment`。临时retain复合也拒绝，当前只支持四牌自身保留。
- 普通力量、虚弱、易伤、敏捷、脆弱仍由共享Actor在成长后的基础值上计算；本模块不提前套用这些修正或发明平行战斗计算。
- Source临时费用在源回合末resetAttributes阶段重置；宿主应保证传入combatCost/turnCost的时点与此契约一致。本模块不擅自重置其他来源的费用覆盖。
- 成长及降费仅属于战斗实例。下一战须从永久牌组cardId/upgraded构造新实例，不能把本战bonus、retainedTurn或cost覆盖复制到新战。源同战斗复制牌、任意外部升级/重置基础值的完整通用协议未新增；已验证历史增量在实例升级标记变化后保留。
- 保留牌仍占真实10手牌容量，下一回合不能绕过满手停止抽牌；本模块不替换共享Draw。

## 当前证据

`node scripts/test-lua.mjs tests/lua/watcher_retain_build.lua`现执行21组全部通过，`WATCHER_RETAIN_BUILD_PASS 21`；`git diff --check`通过。测试基础共享文件从root实验构建树复制，仅用于本组件私有组合验证，不作为此组件的新交付。

覆盖12组模块/源规则检查与9组真实共享入口：Combat.play和主动弃牌后不成长、升级历史、limbo/死亡、当前费用覆盖与0下限、明确不支持组合、新战实例重建；真实endTurn/play使用成长数值；成长和化沙延后降费在敌回合前完成；保留10张后正常抽牌停止；第二张保留牌成长发生数值溢出时，先前第一张已发生的成长、所有实例/牌堆/选择/队列/事件/回合状态及原引用完整恢复；真实Corruption与两张技能跨回合零费使用并消耗；满手还原不触发手牌hook，严格保留原版显示费用与能量合法性门槛；虚无→Restore→DE尾抽→化沙降费的真实帧顺序。

极限值成长同时预检“存储的bonus”及“当前基础值+新bonus”，避免bonus本身合法却生成无法读取的溢出牌定义。满10腐化边界使用明确受控生命周期：在Corruption构造扫描之后向draw加入新实例，再由真实Combat.draw触发临时零费；不把此夹具称为已实现某一张原生生成牌或自然获得该组合的证明。

这些是明确实验数据的共享核心验证，不等于正式随机池、跨色自然获取、中文UI完整显示、通关或平台验收。没有运行全量套件。

## 回合末虚无与普通弃牌的进一步顺序回归

固定源DiscardAtEndOfTurnAction并非先实际执行普通弃牌：它先把保留牌移limbo，再TOP加入Restore，然后TOP加入普通全弃DiscardAction；最后对剩余hand副本执行未指定源流的Collections.shuffle，并调用每张卡的triggerOnEndOfPlayerTurn。AbstractCard对虚无牌再TOP加入ExhaustSpecific。依据LIFO，实际顺序是**虚无消耗→普通自动弃牌→保留恢复→已经排好的DE等尾动作及化沙降费**。

普通全弃取hand尾部getTopCard逐张移动，各次移动才分别调用onCardDrawOrDiscard；结束回合不会触发Tactician/Reflex的手动弃牌回调。源在多个虚无牌之间使用未指定shuffleRng的Collections.shuffle，本片不复现这个外部随机，也不把固定虚无顺序声称为原作随机轨迹。

补充源文件`actions/common/DiscardAction.java`，固定319009原始SHA256：`8c711be291822386b64fe0a6c9bc55b920b7a09122fb55f09184b6ca96063c10`。其他所需源方法及hash已在上表列出。

`node scripts/test-lua.mjs tests/lua/end_turn_discard_order.lua`执行4组真实共享入口回归，`END_TURN_DISCARD_ORDER_PASS 4`，`git diff --check`通过：

1. 单Dazed、Corruption和20费受控普通技能：腐化构造先20→11；回合末虚无消耗的手牌hook仍能看到普通技能，再11→2；普通技能随后弃掉，下一回合真正抽入只改turnCost为0，combatCost保持2。原普通弃牌先执行会错误留下11，正常小费用常被归零幂等性掩盖。
2. 混合普通、单虚无和两张保留牌：exhaust观察帧中普通牌仍在hand，保留牌已离hand；retain帧中普通牌已在discard；化沙成本尾动作在敌回合帧前完成。
3. 无高级清理的普通三牌，同样按hand尾部逐张自动弃牌，不借“快速路径”改成数组正序。
4. 真实Battle Trance施加NoDraw，结束回合先移除NoDraw，再执行虚无；Dark Embrace在保留恢复后真实抽回先前弃掉的Battle Trance，证明后续Draw未被错误阻挡。

全部虚无顺序夹具只含单张Dazed，不对多个虚无之间的外部随机作断言。20费牌是明确的源算术/手牌hook压力夹具，不新增或宣称原版可获取牌。此次只新增测试与说明；共享修复由主线程所有者完成，没有修改冻结核心、提交、推送或运行全量套件。
