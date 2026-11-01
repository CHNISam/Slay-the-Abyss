# Maw 与 Spire Growth 独立切片

本片只增加两个普通遭遇，保持原母队列、权重和其它未实现来源的明确拒绝。当前工作基线的共享玩家轮末阶段尚未接入 Constricted；对应生产回归保留红例，不把数据已注册或临时原型通过当作可集成完成。父线程独立修复共享阶段后再接线验证。临时“仅 Constricted 改阶段”的 Combat patch 已移出生产文件，不作为交付。

固定行为参考为第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的本地只读 ZIP。[来源锁](../../tests/fixtures/act3-maw-growth-source-lock.json) 记录21个原始成员的逐字节 SHA256、方法、独立模型与依赖。未复制 Java 原文到产品，未运行原作 PC 二进制。显示使用已核来源名称，不猜中文译名。

| 固定方法 | A0 合同 |
| --- | --- |
| `Maw` constructor、`AbstractMonster` constructor/setHp | 常量 HP300 的 superclass 参数不抽 HP；Maw 没有调用 setHp，故零次 monsterHpRng 抽样。 |
| `Maw.getMove/takeTurn` | int turnCount 初始1，每次 getMove 先加1，开场即2；真正执行 Roar 才置 roared。Roar 按 Weak3→Frail3 施加，受 Artifact 分别拦截。主抽样小于50且上招不是Nom才选Nom；否则上招Slam/Nom则Drool，其余Slam。每次选招仍消费一次 AI。 |
| `Maw.takeTurn` | Slam25，Drool力量3，Nom为5伤害×Java int(counter/2)，正计数向下取整；不是浮点ceil。连击各次使用真实伤害/格挡/反伤，死亡后后续普通 DamageAction 取消；已排 RollMove 在仍有队友时可继续。 |
| `SpireGrowth` constructor/getMove/takeTurn | source monster ID是`Serpent`，遭遇名是`Spire Growth`。HP170的setHp仍抽0..0一次。A0先按小于50且Tackle未三连选择16伤害；否则未有Constricted且上招非Constrict时施加10；否则Smash22未三连时选择Smash，最后回退Tackle。没有A17开场强制束缚。 |
| `ConstrictedPower`、`ApplyPowerAction` | DEBUFF、priority105。Artifact拦截时不建立来源；成功后记录首次真实source actor，同ID叠层不换Power原来源。结算是玩家轮末THORNS，不是HP_LOSS，不受力量/虚弱/易伤且不递归棘刺，受格挡/Intangible影响。 |
| `ConstrictedPower`、`AbstractMonster.die`、`DamageAction.update` | 固定源没有死亡删除钩子。死来源有队友时仍可造成其THORNS；单怪死后的战斗结束会阻断下一轮，不等于删除Power。新战`AbstractPlayer.preBattlePrep`清状态；未新增“杀来源即移除”的猜测规则。 |

共享阶段需求由源码链限定：GameActionManager.callEndOfTurnActions先执行轮末pre-card powers、orbs与Burn/Regret自动牌；AbstractRoom在isEndingTurn时调用endTurn，再按玩家powers顺序applyEndOfTurnTriggers，之后才排ClearCardQueue和DiscardAtEndOfTurn。Constricted.priority105晚于默认5的Combust、临时力量、Ritual等。Combust与Constricted均已排入DAMAGE尾时，即使Combust杀了最后的source，后续束缚伤害也仍结算；玩家随之死亡只产生败北结局。不能用针对单个敌人的条件搬移来替代共享阶段。

真实来源引用保存在`combat.constrictedSource`；player只投影`constrictedSourceId/Name`原语，避免Events.frame浅投影泄漏活核心actor。Snapshot保留原actor别名；结算不得按当前slot/ID重找来源。Maw每次改变Nom次数时替换该招式定义，旧呈现frame保留旧连击数。Host状态详情只加来源名称说明，无新意图op、布局或平台改动。

[独立 Python 模型](../../tools/oracles/sts1_maw_growth.py) 不读生产 Lua 或游戏数据；`python tools/oracles/sts1_maw_growth.py --lua` 可重生[6条八行动向量](../../tests/fixtures/act3-maw-growth-vectors.lua)，锁HP/AI完整words/counter、实际招式、连击和逐轮伤害。1000HP仅是独立长算式fixture的明确存活输入，不是自然通关或Run/Host注入；真实Run/Host保持角色起始HP与牌组。运行向量按LF归一化锁定，ZIP成员不归一化。

专用`tests/lua/act3_maw_growth.lua`含18组，沿用默认30秒预算；公开房间在seed2/3的原第三队列项分别得到Maw/Growth，来源HP为零/一次抽样，最初真实红为`act_content_unavailable`。仅跳过队列前缀定位章节边界，没有模拟胜利或重抽遭遇。其它用例覆盖真实多段、49/50与历史、Artifact、首次源/叠层、死源/单怪战斗结束、THORNS算式、Burn/Ethereal/Combust顺序、优先级、真实Host、frame隔离与晚失败Run/state/RNG/UID/原引用回滚；扩展规划还拒绝仅同ID的克隆actor，并验证真实死源载荷可通过现有ActionQueue纯数据校验且不进入呈现帧。

尚缺共享hook时，来源身份、Maw及Growth选招、帧隔离和构造回滚通过，Constricted实际阶段/伤害等生产红例保持失败；没有通过删断言或模拟tick让全夹具变绿。既有Orb、Shapes、Act2定向保持通过。未跑全Quality、平台导入或实机验收。正式Buffer/incoming不在本基线，不做一次性兼容消费；组合验证由父线程统一进行。
