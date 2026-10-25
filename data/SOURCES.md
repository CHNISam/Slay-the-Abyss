# 来源与适配边界

2026-10-25 完整75张铁甲战士：正式要求固定为初代PC A0的3张基础牌与72张非基础牌，不再采用30张缩减口径。`reference/warrior75.json`仅保留历史盘点；运行数据已按75张构造、升级、使用及相关能力/动作的固定来源逐张核验，原卡名不改写。逐卡来源身份、方法行段、实现与四层验收见[完整矩阵](../docs/reviews/TASK-16-warrior75-matrix.md)及[固定来源表](../docs/evidence/warrior75/sources.json)。完整消耗动作、UID选牌、复制/X费/持续能力、原红池及共享奖励/商店cardRng已实现候选；Courier身份使用[独立会话熵](../docs/reviews/TASK-16-warrior75-courier.md)。本地逐卡通过不等于平台或原PC严格验收；未实测部分继续保留。下文37张及“不会声称75张可玩”属于历史切片记录，不是当前交付范围。

2026-10-25 清除诅咒祭坛切片：固定 `aeubanks/sts@319009d5` 的 FountainOfCurseRemoval、AbstractPlayer.isCursed 与 CardGroup.removeCard 方法链，接通永久牌组资格、full目录到正式节点及原生界面。泉水不奖励最大生命或回血；保护三张特殊诅咒，实际移除再排除Flame/Lightning瓶装。当前支持Regret，未实现移除钩子的其他诅咒原子拒绝；默认七事件池未改，完整25事件统一切换与平台自然获取仍缺。固定身份、红绿与范围见[本轮记录](../docs/reviews/TASK-13.1.2-fountain.md)。

2026-10-25 用户提供的 `STA_Reverse_Engineering_Pack_20261025.zip` 已作为 M3 TASK-14.1/47 的交互事务规格接入。仅采用药水模块和 POTION-02/03/05 的拒绝、取消与实例身份要求，不将其中 STS2 网站数据作为当前 STS1 运行时数值。固定包身份、基线冲突、生产入口、7组新增回归与分层验收责任见[资料包药水切片](../docs/reviews/M3-PACK-POTION-20261025.md)。这份包不是原作构建认证，也不证明完整内容池或实机通过。

2026-10-24 窃金客有限闭环：现有looter接入A0 HP44–48、Mug10/Lunge12、每次最多偷15、Smoke6与逃跑；逐敌账本，击杀只登记独立STOLEN_GOLD，战后手动领取才返；全逃普通金0但保留卡牌和存活回血6。首/次Mug的0.6f/0.5抽样发生在伤害前，立即/排队SetMove区分；组合PR170保留药水独立领取/放弃和Boss17；全逃普通药水chance0仍抽一次概率并增加修正。完整药水池/原版随机轨迹、PC真实性和平台实测仍未一致。来源hash、真实初始牌闭环、事务边界和表现分层见[TASK-15.16账本](../docs/reviews/TASK-15.16-looter-steal-escape-reward.md)。本条覆盖下文旧“窃金客不偷金逃跑”的现状说明，不更改历史证据。

2026-10-24 Boss宝箱有限切片：独立第17层三选一/跳过，支持Black Blood的起始遗物替换及胜利heal12、Slaver's Collar精英/Boss每回合能量+1、Sozu每回合能量+1及药水获取拒绝；普通商店/宝箱排除Boss遗物。固定镜像方法链、内容hash、受限池/共享LCG边界和离线事务证据见[Boss宝箱账本](../docs/rules/BOSS_TREASURE.md)。不是完整原版池、正常17层通关或平台正式结算验收。
2026-10-24 商店专项：改为固定7牌/3遗物/3药水槽和一次删牌；复用已有binary32价格候选接入浮动、特价、会员卡/快递员/微笑面具交互；快递员与面具本身禁止在商店出售。无色牌、稀有药水/遗物和完整原版池仍缺，空桶显示不可售而不重分稀有度概率。原作共享奖励随机流/偏移历史、全局遗物队列和本候选实机UI仍未验收，见[当前商店账本](../docs/SHOP_PARITY.md)。本条覆盖下文旧的“商店遍历可玩池/最终固定价/不售药水”现状描述，不改变历史证据。

2026-10-24 大型棘刺团分裂切片：TASK-15.13在已有HP/招式之后接通半血打断、行动时当前HP生成两只中型、父体保留但不触发死亡能力、同回合不行动及延后胜利。固定来源中的显式HP构造不抽普通生命；两次新敌首动roll后仍执行父体已排roll。身份安全的事件帧与目标输入、五槽容量及实际控件回归一起修复，见[分裂账本](../docs/reviews/TASK-15.13-large-spike-split.md)。这是现有large_spike普通遭遇的离线机制实现，不是完整软泥/Boss、原作独立随机流、精确动画时间或千星实机验收；下条分裂未实现只描述前一切片。

2026-10-24 大型棘刺团有限切片：固定SpikeSlime_L/M方法链核实HP64–70、30/70双招禁三连、攻击16后Slimed2与Frail2；复用中型决策但保留不同AI kind。真实致死攻击另暴露玩家死后仍塞牌/敌方自盾，按DeathScreen/AbstractRoom链最小停止后续effect，保留当前反应与胜利特例。来源hash、红绿、真实UI及共享LCG/平台限制见[TASK-15.12账本](../docs/reviews/TASK-15.12-large-spike-slime.md)。**半血分裂仍是父任务必要缺口，不声明整只大型敌人一致。**

2026-10-23 红绿虫蜷甲切片：所有HP/咬击构造与开场选招之后，先洗牌再逐只抽取3–7被动值。首次非致命普通伤害立即锁定一次，全部同卡效果、反伤及弃牌完成后按触发顺序获得固定格挡并移除；玩家死亡停止队尾，后续被杀的虫不获盾也不移除状态。原子回滚、真实UI、源码hash及有限队列/共享LCG/平台边界见[TASK-15.11账本](../docs/reviews/TASK-15.11-louse-curl-up.md)。

2026-10-23 红绿虫有限切片：普通HP分别10–15/11–17，每只HP后抽取一次5–7咬击；A0两招25/75选择且均禁三连，开场及每次动作主roll。固定源身份、先红后绿、构造抽样与真实UI/回归见[TASK-15.10账本](../docs/reviews/TASK-15.10-louse-hp-bite-ai.md)。该历史切片未包含Curl Up；后续实现及额外3–7抽样见TASK-15.11。生产仍共享LCG，不宣称完整敌人、随机流或平台一致。

2026-10-23 菌兽死亡能力有限切片：现有蕈甲兽新增菌雾2，按真实死亡、单体/范围伤害反应及末敌清队列边界对玩家施加易伤。空ApplyPower来源与怪物时点分开，Artifact、毒伤、反伤和原地回滚已离线验证；不是完整动作队列/随机流或平台认证。固定13份方法链字节身份、先红后绿及保留缺口见[TASK-15.9账本](../docs/reviews/TASK-15.9-fungi-death-power.md)。下条TASK-15.8的“尚未实现”是当时切片边界，不再代表本片后的状态。

2026-10-23 蕈甲兽生命/选招有限切片：固定FungiBeast及AbstractMonster/RollMoveAction方法链核实A0生命22–28、0–59攻击/60–99增力、禁三连攻击/禁连续增力、开场及每次动作主roll。保留基础伤害6/力量3，未改死亡钩子。Spore Cloud死亡易伤2仍是现有可玩池严格缺口，不宣称整只敌人完整；来源hash、红绿、共享LCG和平台限制见[TASK-15.8账本](../docs/reviews/TASK-15.8-fungi-hp-ai.md)。

2026-10-23 中型酸液团A0切片：固定AcidSlime_M/Random方法体核实HP28–32、30/40/30三招及条件Boolean回退、7伤害后Slimed1/普通10伤害/Weak1。只覆盖现有直接生成敌人，复用PR136污染牌和队列接口；来源hash、红绿、0.4f精度与共享LCG/分裂/平台限制见[TASK-15.7账本](../docs/reviews/TASK-15.7-acid-slime-m.md)。不新增卡池，不声明原作完整随机分布或平台一致。

> **规则基线**：历史“适配/简化”不代表获准的最终规则。首发可玩范围按初代 Slay the Spire PC Ascension 0 逐项核对；已修正与剩余偏差以下方专项证据为准，见 [RULE_PARITY.md](../docs/RULE_PARITY.md)。

2026-10-23 中型棘刺团A0切片：固定SpikeSlime_M/Slimed及已排动作方法链核实HP28–32、30/70双动作禁三连、攻击8后塞1张真实费用1可消耗状态牌。只为slimed开放受限空use，保留任意空效果拒绝、奖励/商店/升级隔离与末敌清队列；同伴仍存时荆棘死后的已排塞牌继续。来源hash、红绿及共享LCG/分裂/平台限制见[TASK-15.6账本](../docs/reviews/TASK-15.6-spike-slime-m.md)。不新增奖励牌、不声明全池或原作PC/平台一致。

2026-10-23 护盾小魔A0切片：固定GremlinTsundere与GainBlockRandomMonsterAction核实HP12–15、开场Protect7随机队友/空列表自身、单队友仍消耗aiRng、独处后永久Bash6；同时按MonsterStartTurnAction/MonsterGroup/Poison/GameActionManager修复全部清盾→全部已支持开始状态→敌方动作，避免后排抹去新格挡。来源hash、红绿及随机流/逃跑/编组/平台限制见[TASK-15.5账本](../docs/reviews/TASK-15.5-shield-gremlin.md)。只覆盖已支持第一幕行为，不能据此宣称全敌人或平台一致。

2026-10-23 蓄能小魔开场抽样切片：固定GremlinWizard、AbstractMonster与Random方法链确认开场即使固定Charge也消费一次0–99主roll；后续Charge/Attack用SetMove，不新增roll。原HP21–25、伤害25和0/0/25节奏保持，来源hash、12组红绿及共享LCG对洗牌/奖励的已知影响见[专项账本](../docs/reviews/TASK-15.1-wizard-opening-roll.md)。不是正版PC认证、原版独立随机流或平台实测，全池/平台AC仍保留。

2026-10-23 哨卫A0切片：固定Sentry方法体核HP38–42、Artifact1、完整敌方列表奇偶错位首动（外侧Bolt2 Dazed/中间Beam9）、此后交替及每次主roll消费；旧Weak替代已移除，使用真实Dazed生成接口。Actor人工制品基础与三敌入口分阶段验证，真实牌/瓶桥接另记。来源hash及认证边界见[专项账本](../docs/reviews/TASK-15-sentries-ai.md)与[Dazed账本](../docs/rules/DAZED_STATUS_CARDS.md)，非官方源码、PC或平台实测，RNG与全池AC仍保留。

2026-10-23 固定动作小魔roll切片：固定GremlinFat/GremlinThief与SetMoveAction方法体确认Fat首动与正常行动末均消费主roll，Sneaky仅首动roll，后续SetMove无抽样；保留已核对HP/伤害/Weak，不把两只盲配相同策略。来源hash、8组红绿及共享队列/LCG限制见[专项账本](../docs/reviews/TASK-15-fixed-gremlin-rolls.md)。逃跑/通知、五敌编组、原版随机流和平台AC仍保留，非官方或PC实测。

2026-10-23 小型棘刺团A0切片：固定SpikeSlime_S核查HP10–14、基础攻击5，首动及每次活体行动末即使固定动作仍消耗主roll。另固定队列方法链发现Thorns致死后“有同伴保留已排roll/末敌清roll”共享差异，已写独立红例交战斗时序切片；Blue/Nob/Jaw旧死亡保护断言不再被扩推为原作消费证明。来源hash、8组专项与边界见[账本](../docs/reviews/TASK-15-spike-slime-s-ai.md)。不是官方源码、原作PC或平台验收，原版随机流仍保留。

2026-10-23 小型酸液团A0切片：固定社区AcidSlime_S与Random方法体核查HP8–12、基础攻击3/Weak1，开场先消耗主roll再额外Boolean选择动作，之后严格交替而不再roll。来源hash、9组独立回归及共享LCG/布尔适配限制见[专项账本](../docs/reviews/TASK-15-acid-slime-s-ai.md)。没有分裂或继承中毒实现，不是官方源码、原作PC或平台实测；旧固定HP/首动说明对此敌人已被覆盖。

2026-10-23 蓝衣束缚者A0选招切片：复核固定社区SlaverBlue方法体后保留已实现HP46–50、Stab12、Rake7后Weak1；新增随机首动与40边界选招、双动作均不连续三次、历史强制仍消耗主roll。来源hash、900组受控输入及共享LCG/Weak时序限制见[专项账本](../docs/reviews/TASK-15-blue-slaver-ai.md)。不是官方源码、原作PC或平台实测；旧固定循环说明对此敌人已被覆盖。

2026-10-23 怒焰巨魔A0生产切片：固定社区反编译镜像核查HP82–86、开场Enrage2、Skull Bash基础6后易伤2、Bull Rush基础14；按33边界选择攻击，Bull Rush不连续三次，技能牌在效果前触发力量。来源文件hash、队列次序、900组受控决策和共享LCG等剩余差异见[专项账本](../docs/reviews/TASK-15-gremlin-nob-ai.md)。不是官方源码、原作PC或平台实测；旧固定循环说明对此敌人不再适用。

2026-10-23 持续状态轮末切片：据固定社区反编译镜像的 WeakPower/FrailPower/VulnerablePower、ApplyPowerAction 与 MonsterGroup 方法体，将三个持续状态从 owner 回合结束衰减改为整组敌人行动后的轮末；新怪物来源首次施加跳过一次，已有状态叠加不刷新跳过。Vulnerable 首次跳过额外要求玩家已结束回合。来源版本真实性、逐方法 blob、独立输入预期及保留的 power priority/随机流/平台缺口见[轮末账本](../docs/rules/ROUND_DEBUFF_DURATION.md)。未宣称完整原版或实机一致。

2026-10-23 石颚兽生产切片：据[开发者公开getMove](https://www.reddit.com/r/slaythespire/comments/1klwcgf/true_jaw_worm_ai/msefy12/)及固定镜像方法体，HP40–44、首动11伤害、Thrash7后5格挡、Bellow3力量后6格挡；按25/55边界及Java float条件抽样处理历史限制，替换旧固定循环。来源hash、首动抽样、独立预期与保留的共享LCG/非原版随机流差异见[专项账本](../docs/reviews/TASK-15-jaw-worm-ai.md)。不是原作二进制或平台验收。

2026-10-23 祈火徒运行时切片覆盖下文旧固定循环说明：生命48–54实际采样，首动施加仪式3且不立即加力量，此后基础6攻击，每个整组敌方回合结束增长3力量，跳过施加当轮。固定方法体来源及真实性/随机流限制见 [TASK-15运行时账本](../docs/reviews/TASK-15-cultist-runtime.md)。不是正版二进制或平台实测通过；其他敌人的差异继续保留。
2026-10-23 深渊守卫离线切片：A0常数先参考社区wiki/DB，再只读核实[固定镜像TheGuardian方法体](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/TheGuardian.java#L236-L293)及真实卡牌/动作队列。该镜像声明V2.3.4/2022-12-18，未经正版二进制hash核验，不是官方开源或本轮原作实测。Sharp Hide与Iron Wave次序另交叉[TCK测试答案Problem 1(g)](https://tck.mn/videogame/stsexam/OLD_stsexam1-v1-solu-v1.pdf)。对同卡多段转形、反刺消耗预算和Twin Slam延后重置，采用具体方法调用链纠正wiki摘要不足。来源、hash、24组独立规则轨迹及证据等级见docs/reviews/TASK-17-guardian-ai.md，不据此宣称整体原版或平台通过。

核对日期 2026-10-22（后续局部复核见下文）。参考初代 Slay the Spire，不引用二代。不搬运图片、程序、存档或长文，中文效果文案由本项目编写。基准为 Ascension 0；旧表的固定生命近似仍属待补缺口，已核实并支持 hpRange 的敌人按范围实际采样。

2026-10-23 节点切片覆盖旧说明：商店删牌已修复每店仅一次；原虚构金币/药水二选一事件已移除，支持初代第一幕 The Cleric（[来源及修订](https://slaythespire.wiki.gg/wiki/The_Cleric?oldid=55508)）：至少35金币才可出现；治疗花35，回复最大HP25%向下取整；A0净化花50按UID删牌；离开无收益或代价。另支持 [Purifier](https://slaythespire.wiki.gg/wiki/Purifier)：祈祷免费删一张所选牌，或离开。`rules.events.encounterId` 当前显式固定为Purifier，是支持内容基线；**不是原版完整事件池、未知房转类或神龛概率算法**，不会按低金币条件改roll。Cleric可由明确eventId或配置指定。金额来自 `rules.events`。详见 `docs/NODE_ECONOMY_PARITY.md`；没有原作客户端版本或直接观察证据，不计严格全项通过。

- 卡牌：https://slaythespire.wiki.gg/wiki/Ironclad_Cards ，单卡按英文 id 对应同名页，例如 https://slaythespire.wiki.gg/wiki/Bash 。
- 普通敌人与遭遇：https://slaythespire.wiki.gg/wiki/Monsters ，例如 https://slaythespire.wiki.gg/wiki/Jaw_Worm 与 https://slaythespire.wiki.gg/wiki/Cultist 。
- 精英：https://slaythespire.wiki.gg/wiki/Elites ，Boss：https://slaythespire.wiki.gg/wiki/The_Guardian 。
- 遗物：https://slaythespire.wiki.gg/wiki/Relics ，药水：https://slaythespire.wiki.gg/wiki/Potions 。

完整75卡来源表由另一会话提交1d04cf2，本分支原样保存在reference/warrior75.json；其中有6张费用待核实及未映射的效果/触发器，不能直接用作运行时数据。首轮37张均来自该战士参考表，采用统一op表达，血液操控升级伤害按来源修为20；X费用以costMode=all_energy表达。不会声称75张可玩。

历史适配记录（仍是待补机制，不能视为原版验收）：除沉眠遗卫、深渊守卫外敌人仍固定意图循环；护盾小魔格挡给自己；符文哨卫施加虚弱代替塞入眩晕。五种小魔出现在一个五敌遭遇中，待通关测试评估强度。大型软泥不分裂；窃金客不偷金逃跑。这里的适配不意味着数值已经平衡。

2026-10-23 沉眠遗卫离线切片：对照 [初代 Lagavulin wiki](https://slay-the-spire.fandom.com/wiki/Lagavulin) 的睡眠/唤醒时序，并以 [SlaySpireDB 初代条目](https://slayspiredb.com/sts1/monsters/lagavulin) 复核 A0 数值。两者为社区二手资料，不是官方源码或本轮原版实测。A0 生命范围109–111，Combat使用战斗种子实际采样（旧112属于A8+范围）；睡眠格挡8、自然睡眠3回合、HP损失唤醒并眩晕当次行动、苏醒后18伤害两次与敏捷/力量各-1循环。详细证据、测试及剩余缺口见 docs/reviews/TASK-15-lagavulin-ai.md。

地图计层已按 `docs/reviews/TASK-12.4-map-floor-evidence.md` 的固定提交来源链修正为15生成行、Boss16、Boss宝箱17，强制普通战斗1/宝箱9/营地15及早期限制。该证据来自明确版本字段但未经正版二进制核验的社区反编译镜像，不能视为官方开源或原作实测。三列拓扑、节点权重、遭遇池/随机流仍为未对齐候选；第17层只有独立入口，Boss遗物池/真实宝箱事务未实现。初始80生命、3能量、5抽牌、10手牌上限与其他固定奖励/价格的核对归各自任务，不声称整个地图照搬原作。

本任务仅验收内容基线与数据校验。未编译平台逻辑、未导入存档、未运行游戏、未获得 Furinya 体验验收。

药水 damage/block 与遗物 block 采用固定数值，不套用卡牌攻击/格挡修正。2026-10-23 首发逐件核对见 [TASK-14.1 账本](../docs/reviews/TASK-14.1-inventory-parity.md)：Dexterity/Frail 限定来自卡牌的格挡，因此固定 Block Potion 不应被一概当作简化而修改。铜鳞稀有度已由 Uncommon 改正为 Common，0 伤害普通攻击仍触发 Thorns；[六件开战遗物顺序](../docs/reviews/TASK-14.1-opening-relic-order.md) 已依据固定反编译镜像修复并通过 20 组回归。镜像不等于认证 PC 构建；完整开战钩子、原作/平台实测尚未完成，不声明全量严格一致。生成手牌满手进入弃牌堆。战斗状态与生成牌在战后清理，永久卡组、升级、生命和资产跨节点保留，具体时序见 README。
