# TASK-15.16 · 窃金客偷金、逃跑与独立取回失金

## 范围和证据等级

2026-10-24，初始基线 `53a52bb3cd4c2e49fa2abe83d9f8e7155e433b99`，随后三方整合真实 develop `e3310bcf91d456b08ed7c231340b20a133083134`（PR169），再与 PR170 head `1b36dfc469aed8f21de7055780b8d726f8c2cfeb` 接合，最终更新至 `17ebb0926faa10a7e45ec4084e3d833bd9fd281b` / develop `f282a9555caa0790f6f3e25011ae91d4e21c77ba`（已含PR171），PR170合入后的实际develop基线为 `f065b7d417bf6f758d938ca38f994dba5206a464`，任务分支 `feat/looter-steal-escape-reward`，PR #168。只接现有 `looter` / `looter_solo`，名称保留“窃金客”，角色和初始牌组不改，不扩 Mugger、遭遇或完整奖励系统。

本片在一个 PR 内先接独立领奖，再接偷金、逃跑和真实死亡登记；不交付只偷不返的半链。所有原作来源固定为社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。已重新计算下列13份保存原文的 Git blob 与 SHA256，全部匹配先前远端核验记录。没有认证正版 PC 构建、版本、二进制 hash 或运行原作，不称“官方 PC 验证”。

## 来源到实现

| 来源方法链 | 已实施合同 | 实现 |
|---|---|---|
| Looter 构造、getMove、takeTurn | A0 HP44–48；Mug10 / Lunge12；每次最多偷15；Smoke6；两次Mug后50%Smoke或Lunge，Lunge后Smoke，随后Escape | enemies.json、abyss_looter_ai |
| Looter.takeTurn、Random.randomBoolean | 开场主roll仍消费；首Mug 0.6f台词、次Mug0.5分支都在damage前；0.6f按binary32值0.6000000238418579，严格小于；立即/排队SetMove区分，不多抽后续主roll | EnemyAI.beforeAction接capturedIntent，Looter.beforeAction/afterAction |
| Looter.takeTurn、DamageAction | 每敌独立累计实际min(15,当前余额)，先记账/扣金再伤害；完全格挡、0伤害仍偷；不负金 | Combat.player.gold、enemy.stolenGold、gold_stolen事件 |
| Looter.die、AbstractRoom.addStolenGoldToRewards、RewardItem.claimReward | 真实死亡只登记独立STOLEN_GOLD；多死合并，领奖才返；不套普通金币加成；合法重复伤害不会重复登记 | Actor死亡边沿、Combat.stolenGoldReward、Run.claimStolenGoldReward |
| EscapeAction、AbstractMonster.escape、MonsterGroup | 逃跑不是死亡，HP/数组/对象身份保留；目标、行动、状态与存活判断排除；不返金；一死一逃不等于全逃 | Actors.isActive、Combat.escapeEnemy/allEnemiesEscaped |
| AbstractRoom.endBattle、AbstractPlayer.onVictory、BurningBlood.onVictory | 存活玩家照常回6；全逃普通金0但仍卡牌奖励；玩家同时死亡优先败；项目victories仍按完成战斗场次+1，未擅改为击杀计数 | Run.finishCombat / lastResult.allEnemiesEscaped、mugged |
| CombatRewardScreen领取移除、现有Run API | 选牌和取回独立、一次领取、明确离开可放弃；原无失金自动回图路径保留 | rewards.stolenGold、cardResolved、manualContinue及3个命令 |

`Run.play/endTurn/usePotion`成功后同步战内余额，进入下一战使用已提交的金币。被偷金额来自各敌对象，不挂共用账本；最终死亡登记在现有死亡能力早退之前。逃跑保留正常 `victory/defeat/nil` ABI，通过标记区分，界面不把全逃称为“全灭”。

## 事务与随机边界

- 新领取命令校验阶段、item类型、claimed及非负安全整数，检查相加上限后才同时加钱/标已领；无RNG、无卡牌和HP副作用。重复、非法或过期动作拒绝。
- 既有 `Combat.play` 原地回滚天然覆盖新actor/state平面字段；既有 `Run.usePotion` 在candidate中完成死亡登记与奖励随机，再原子提交。没有另造存档或事务框架。
- 明确保留既有边界：`Combat.endTurn` 和 `Run.finishCombat` 不是任意运行时异常事务。对 `53a52bb` 真实初始牌组普通Cultist终击，在奖励采样人为抛错，同样保留已结算伤害、金币/回血、seed与事件。Looter逃跑的同类故障诊断也保留，不将旧边界隐藏为新验收绿，不因本片扩成通用Run事务。
- 生产仍使用共享16位LCG。范围请求、调用顺序与binary32阈值已核，但不是原版完整独立HP/AI/card/treasure/potion流，也不是相同seed映射。纯边界夹具与真实seed轨迹分别取证。
- 组合继承 PR170 的受限药水 provider：普通战后 drop/rarity/content 使用连续 `shopRng.potion` 流，新增 `prepare(run, rewardCount, context)` 可选上下文仅对 normal 全逃将 chance 置0。仍消费一次0–99概率抽样并 modifier+10，不生成后丢弃、不抽rarity/content。原作 White Beast Statue 后置100再由 rewards.size>=4置0；白兽未支持，不新造遗物。PR170既有rewardCount=2保持不变；源是添加卡牌前的房间reward数量，不能把项目cards计入的固定2称为原作时机。普通非全逃金币仍走固定tier自动入账。
- Map现有snapshot/restore只恢复地图，同一Run跨节点状态保留。本片不新增完整Run持久化/退出续局格式。

## UI和表现边界

复用批准主题、presetButton四态和既有输入所有权。新增“取回失金”和明确离开，卡牌/失金分开处理；manual奖励下所有卡与动作持有run、battle、rewards、item、claimed、cardResolved、render身份，以及cards数组/choices、item amount/type与manualContinue快照；药水动作、卡牌与其他奖励同时核potion对象、resolved/result/id/unavailable，重绘、替换、模态、重开和重复旧手势拒绝。click-only宿主兼容保留。无失金且没有任何权威状态变化的纯render保留170既有手势语义；替换对象、金额/choices/manual模式变化仍拒绝旧输入。manual真实render撤销旧手势，纯动画render(true)不撤销。

金币HUD读取当前播放帧的player.gold，而不是提前显示已提交的最终余额。窃金意图明确说明最多15且完全格挡仍偷；逃跑意图明确不返金。

来源 `AbstractMonster.escape()` 使用3秒timer。本片增加独立 `enemy_escape` 事件和主题 `motion.enemyEscape=3`，显示逃离通知并在该时段后移出画面；不借death动画、死亡音效或hp=0模拟逃跑。此为有限表现，不含原作骨骼/SmokeBomb VFX的完整等价演出；离线时钟断言不是千星实机计时认证。

已接入 PR #169 的单一居中选牌台：保留其1.38倍卡牌、1.5倍hover、入场、台下skip和隐藏战斗牌堆。manual模式新增取金/离开与skip共用台下行及rewardPick间距；选/跳后面板保留、卡片隐藏，失金仍可领。纯入场/hover绘制不作输入身份代数更新，显式重绘/对象变化/模态仍废弃旧输入。新增组合红例曾捕获动画吞掉正常手势，修后通过；未新增第二套modal，不冒称完整PR19奖励三行或平台UI验收。

## PR170奖励与Boss宝箱接合

无失金的选/跳卡路径完整保留170：自动收下可得药水，满槽或Sozu拒绝整条选牌，需先单独放弃。只有STOLEN_GOLD存在时启用manualContinue，卡牌、失金、药水分别处理；leave在药水未resolved时原子拒绝，玩家需单独领取或明确放弃。药水处理后可明确离开并放弃未领的卡牌/失金。Sozu沿170保留领取拒绝+明确放弃，和固定镜像RewardItem中消费奖励但不入槽的细节不同，不声称全一致。

Run只返回map，不直接触发victory。保留170的GameUI.refresh→Nodes.completeCombat→boss_victory→地图独立17层入口→claimBossTreasure领取或跳过才胜利。真实Boss不偷金；合成Boss账本夹具只核组合转场，不作正常Boss证明。

五动作共用既有居中选牌台下行；有瓶manual时按skip/primary/secondary实际半宽和space.m计算，安全区内保留间距，无失金170位置和无瓶168位置不变。普通卡牌动画不废弃有效输入。

末击药水既有candidate事务补复制shopRng：170新增provider会提交其potion成员，若随后异常，不能通过浅拷贝泄漏到旧Run。独立原170真实末击控制也复现这一别名边界；修复不扩大endTurn事务。

最终更新保留PR171全部开场演出、商人对话与主题。与168仅3个重叠文件：theme/ui-layout自动三方接入；BattleUI保留171层数/战斗类型title的同时保留168播放帧金币HUD。没有改prologue/merchant/GameUI/NodeUI逻辑或使用旧文件覆盖新演出。

## 可复现测试与真实路径

新增仓库测试：

- `tests/lua/looter_runtime.lua`：真实Run42，原80HP/99金/初始牌组，floor4为既有合法遭遇前置；首Mug余额84、第二次69，不出牌最迟第五动逃离，普通金0、卡3、存活回6、victories+1。
- `tests/lua/looter_closed_loop.lua`：真实Run1初始牌组击杀，turn4、实际被偷45、战后余额69；取回后114。取金/选牌/跳过/离开四顺序与下一战账本隔离；另以明确标注的1HP/Thorns边界夹具检查同时死亡优先败。
- `tests/lua/looter_rules.lua`：HP闭区间、每敌账本、0/8/20低金边界、真实seed3两Defend全挡仍偷、50%边界、致死前RNG、普通/毒/反伤/火瓶死亡入口、逃跑目标排除及现有card rollback。
- `tests/lua/looter_rewards.lua`：真实普通胜利无失金旧路径控制；独立账本合同夹具验证无即时加钱、两顺序、跳过/离开、重复和非法上限拒绝。合同夹具不当成真实窃金机制证明。
- `tests/lua/looter_reward_ui.lua`、`looter_feedback_ui.lua`、`looter_reward_stage.lua`：真实生成原生树，独立领取/离开、stale手势、播放帧金币与独立3秒逃跑，不调用死亡表现。
- `tests/lua/looter_potion_rewards.lua`、`looter_potion_ui.lua`：与170的自动领取控制、独立卡/钱/瓶、满槽/Sozu、旧offer与交叉动作、全逃概率流、末击药水故障回滚和Boss16→17接合。核心首跑2过7红后转绿；UI首跑1过5红，加安全区红例后转绿；独立state-identity100项曾38红，补cards数组/choices、stolen amount/type、manualContinue快照后100/100绿；另8个无失金纯render探针只是可选输入收紧，不是新业务缺陷；最终按最小范围撤回该收紧，并正向验证170旧手势语义及动画。
- `tests/looter-ai-data.test.mjs`：A0数据及限定escape策略、未知键/非法引用/概率/空攻击拒绝，JSON字段顺序不影响合法效果。

初始真实Run红例：首动金币99而预期84。A段领奖5组首次1过4红、UI3组全红；B段规则8组首次全红、feedback2组全红。逐步绿后，独立规则/生命周期/领奖/原生控件审查继续校验。历史e331冻结组合本地148/148 Lua通过（含旧141文件和7个本片文件；battle_ui为54组、card_help_release保持31组），Looter+既有Louse数据45/45 Node测试、数据校验和JS语法检查通过。原生控件树2025控件、最大直接子项54，不超过60限制。独立核心冻结16文件复核29组、9个负控全绿；完整新UI与动画矩阵见最终独立报告，不拿过程中旧日志充作冻结证据。

历史PR170 1b36组合重跑：155/155 native Lua文件、Python17/17、数据schema/JS语法通过。选定Node数据/布局共72项，71过；唯一map-ui-layout中的Fengari桥接用例因本环境缺依赖阻断，同名native map_ui文件通过，未安装或换造运行器冒充原检查。真实Run seed2初始牌击杀在turn3同时获得待返30和energy_potion：战后84金，先选牌不收瓶，leave拒绝，分别取金/领瓶后114金和11张牌，重复领取拒绝且potion RNG仍3次。floor4仅合法遭遇前置。

原170只读策略与命令审计不变，seed3/42自然完成17层（HP25/34，金币105/131），均未碰looter_solo；不能拿这两条替代上面的真实Looter闭环。扩展审计seed1/2/36分别在16/5/16层正常战败，未调数值制造通关。旧审计脚本在seed1取卡后立即completeCombat触发reward_pending，最小增加合法取回失金/明确离开命令及重复拒绝记录，未改决策或路线。药水新增流解释为shopRng.potion与potionChanceModifier，不能把e331无provider旧快照直接当组合期望或宣称battleLCG被额外药水抽样污染。

历史1b36组合生成game-ui树2081控件、最大直接子项57，未超过60限制。

最终17ebb/171组合重新执行156/156 native Lua文件、Python17/17、schema与JS语法；选定Node72项中71过/1个Fengari桥接环境阻断。生成game-ui2182控件、最大直接子项57。PR171新增开场10组及商店/退出回归包含在本轮新跑，不借用旧组合计数。独立reviewer按最终源另行重建，报告计数不与历史叠加。

本地命令不安装 npm 或 Fengari：现成 native Lua5.4 helper 执行 Lua 文件，`node scripts/build-lua-data.mjs`、`node scripts/build-ui.mjs` 和 Node builtin tests。原工程正式 `npm run check` 在远端CI由主线程执行；本地主题JS测试中的一个Fengari加载用例因依赖不在此目录而失败，native主题/全Lua验证另列，不掩盖也不通过安装绕过。

数据、本地Lua、JS/schema、平台候选编译、官方导入和千星实机均为不同层级。此次未启动游戏、未官方导入、未取得手机/电脑实机截图；父TASK-15全敌池/严格来源及平台AC、TASK-13.1完整奖励/RNG缺口仍保留。

## 固定来源身份

| 原文 | Git blob SHA | SHA256 |
|---|---|---|
| [actions/common/DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `ea89aeab60af8a7c297495de3cd8eb82d7130232` | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| [actions/common/EscapeAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/EscapeAction.java) | `18027317774535bcfde2898a32e97a4250dc95bd` | `ffbe3b6d2ed290255005b61c5d88c1b470ae9d05eb87462004ac98382051498c` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `dc0f077c70ff36bad5d602f2128be1db1a0ee5b7` | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [monsters/MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `7096970a151840489a3fba89806e6391e0d82d76` | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| [monsters/exordium/Looter.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Looter.java) | `62180226216c6e8fa1739b46b81e60e62a9be457` | `8e4a94a8f8404a3ed64f5fa12dd301d597bc86abc0d750d7b296daf5663ce0cc` |
| [powers/ThieveryPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThieveryPower.java) | `e59026bf7a29259ebfc8b830c750fe4ecacb0dd6` | `cf0ba1148ca2c7dba64991bf2f9de7d2ef762c2799f05d2dd40ae743488083ec` |
| [rewards/RewardItem.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/RewardItem.java) | `a23c192d58c6304acd76505da7365490636f1f31` | `4287fb3caf3a6ad04fd7c09d1d272bc7e98ceecf4a4d599131c3a68467f75859` |
| [rooms/AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) | `c2a1a029a9f59b1b94026dff46d4155824b85f86` | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` |
| [screens/CombatRewardScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/CombatRewardScreen.java) | `b14151ac95f94dea592226932495d8d225ea4640` | `7929ca75599e96c076f9abe2c90576a606c87984174328d10533ada8ee37e70b` |
| [random/Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | `c4b71d5645688f6e764c46c593223eb91a5249bc` | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` |
| [actions/common/SetMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SetMoveAction.java) | `3d06fd9e29345de1c7c9d35c473543a2c7f041e3` | `2b6c9200a4574d514674214d342a24993d6bd7f9ce1ac81306fd308adb443666` |
| [relics/BurningBlood.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/BurningBlood.java) | `3b262d9830955000488efc98bcc5c9b56e77fea4` | `8217a4a05a80474158ade3f7d77e51f802c9701512bbf1ab90321d7f74d5d65d` |

额外方法定位：Random79–82严格nextFloat()<chance；SetMoveAction50–52无死亡门禁；BurningBlood26–32存活heal6。AbstractRoom309–330区分普通金与卡牌/药水路径，415–424触发onVictory，582–609为药水概率及RNG；MonsterGroup119–125为全部escaped判定，AbstractPlayer1933–1942转发遗物胜利钩子。

最终上游合入核验：f065b7d417bf6f758d938ca38f994dba5206a464 与17ebb共享Git tree `c3a25e91cd6b7131d05019bc2e6487fc3598e81f`。最终追加独立正式 `potion_reward_atomic.lua` 四组自然末击成功/抛错/拒绝/旧形状回滚测试，以及只共享无捕获方法的两处原生UI测试helper；既有测试体和时间预算未改，不影响生产。最终native157/157文件通过；此前156计数只属于追加前冻结，不叠加宣称新总数。


## 2026-10-24 CI 超时后的测试分片

代码提交 b3b967 的完整 Quality 已成功；最终收口 7f1fe9 在旧 Windows runner 的 looter_potion_ui.lua 单入口 30 秒处超时（Quality 40082506794 / job 120838773571），不能据先前成功宣称本次通过。任务最终CI/集成项已重新打开。

仅将原 74 次完整真实树夹具拆成基础 24 次、held 25 次、released 25 次三个入口；全部数据、动作、断言和 50 项身份矩阵保持。独立逐 case 比较 setup、事件、状态、对象归属、RNG及控件树记录等价，去掉新增身份保护的负例仍被矩阵捕获。原生 Lua 全套由 157 文件变为 159 文件并全部通过，但不是 Fengari/Windows 性能认证。每入口仍默认 30 秒，三入口可用超时上界由原 30 秒合计增至 90 秒，总作业仍 20 分钟；未删用例、未修改生产或降低真实验收要求。实际效果以新提交完整 CI 为准。
