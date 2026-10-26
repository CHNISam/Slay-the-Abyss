# 第二幕敌人实现记录

TASK-61完整范围不变。本文件只记录独立完成的怪物组，不能视为第二幕全量验收。没有候选构建、官方导入或实机证据。

固定行为来源：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，第三方反编译镜像；本轮从根目录`.artifacts/m3-pr193-worktree-evidence/sts1-relic-pool-catalog/.artifacts/relic-source/archive/`只读核对，未复制Java原文或素材进产品。数值以PC A0分支为准，Lua是独立实现。

| 已实现敌人 | 核对的方法与事实 |
| --- | --- |
| SphericGuardian | constructor不调用setHp，HP20且不消费HP随机；preBattle为Barricade、Artifact3、格挡40；getMove依次激活25格挡、10伤害/脆弱5，然后10×2与先格挡15再10伤害交替。每次初始化/行动仍消费100范围AI抽样。 |
| Centurion | HP76–80，Slash12/Fury6×3/Protect15；65阈值，保护和狂怒各禁三连，斩击禁三连；存活人数决定保护或狂怒。GainBlockRandomMonsterAction消费AI流，即使仅一个队友。 |
| Healer（本地mystic） | HP48–56，8伤害/脆弱2，全体治疗16或力量2；所有活怪缺血总和>15优先治疗，治疗禁三连；40阈值与攻击、强化禁三连。 |
| Taskmaster | HP54–60；super参数先做一次HP随机，setHp再做一次；7伤害并将1伤口入弃牌堆，无A18力量。反伤死亡时已有伤口动作在队友存活期间继续。 |
| BookOfStabbing | HP160–164，6伤害多刺，21伤害重刺；15阈值，重刺禁连、普通刺禁三连；多刺计数初值1且每次选择多刺前+1；PainfulStabs仅每次实际生命伤害生成1伤口，格挡与Thorns不触发。 |
| SnakePlant | HP75–79，7×3或脆弱2/虚弱2；65阈值，普通攻击禁三连、孢子禁连。Malleable初值3，非致命NORMAL生命伤害把当前格挡值排到BOTTOM后+1，所有已排队命中完成后结算，敌人行动结束重置3。 |
| Champ | HP420；斩击16、处决10×2、掌击12/脆弱2/易伤2、嘲讽虚弱2/易伤2、强化力量2、怒吼移除负面及Shackled后力量6。getMove严格低于半血才转阶段，每四次选招嘲讽，防御最多2次（格挡15、Metallicize5），处决间隔两个动作；15/30/55边界均按原始闭区间。 |
| Chosen | HP95–99；A0先5×2，再施加Hex1；之后交替在10伤害/易伤2与虚弱3/力量3之间按50阈值选择，在18伤害与5×2之间按40阈值选择。Hex受Artifact拦截；使用非攻击牌才生成Dazed，空抽牌堆不抽随机，非空在0..size-1插入，原顶牌保持。 |
| ShelledParasite | HP68–72；14层PlatedArmor/初始格挡14；开场100范围AI抽样后额外真实Boolean决定6×2或吸血10。20/60阈值、Fell18/脆弱2不连发（重复时另抽20..99），其余动作禁三连；普通攻击造成生命伤害逐层削甲，破甲动作排BOTTOM后晕眩，晕眩行动先SetMove(Fell)再RollMove。吸血仅治疗实际生命伤害，死亡攻击者不治疗。 |
| Byrd | HP25–31，Flight3；1×5啄击、12俯冲、力量1鸣叫。首次37.5%鸣叫；50/70主阈值及40%、37.5%、28.57%次级真实Boolean保留binary32参数。Flight减半，削层和落地排BOTTOM，完全格挡/THORNS/HP_LOSS不削层；敌人行动前补满3；落地晕眩→头槌3→升空，头槌直接SetMove不抽AI。 |
| Snecko | HP114–120；首次施加Confusion，之后40阈值在尾击8/易伤2与咬击15间选择，咬击禁三连。Confusion优先级0，每次抽到费用非负牌真实抽0..3并持久修改费用，同值保留旧临时费用，X费和不能打出的牌不抽。Artifact可拦截Confusion。 |
| Mugger | HP48–52；Mug10、Lunge16、Smoke格挡11，盗金15。不同于Looter，Mug/Lunge与死亡的音效各真实消费AI整数0..2；第二次Mug才抽0.6谈话Boolean；第二次Mug另抽0.5决定Smoke或Lunge。复用同源窃金、逃跑、单独返还盗金事务，二盗贼严格为Looter+Mugger。 |
| GremlinLeader | HP140–148；初始两个随从从8项原权重池由misc有放回抽取。6×3攻击、鼓舞全体力量3且仅队友格挡6、召唤两次；鼓舞引言消费AI整数0..2。按活随从0/1/2+分别用75、50/80、66阈值选择，并保留50..99和0..80递归重抽。召唤由AI抽原8项池，最多三槽，先完整构造后初始化，按原X位置插入且本回合不行动；标记Minion，首领死亡后其他怪逃跑。 |
| Collector/TorchHead | Boss282HP，首次召2只TorchHead，第四次行动前选择一次虚弱/易伤/脆弱各3。18火球、格挡15/全体力量3；25/70闭区间阈值、火球禁三连、强化/复活禁连。死槽重建新Torch身份不复用尸体；Torch38–40HP、构造双HP抽样、初始化抽100一次，之后7伤害/SetMove无后续roll；首领死后随从自杀。 |
| BronzeAutomaton/BronzeOrb | Boss300HP/Artifact3，先召2Orb；Flail7×2/Boost格挡9力量3循环，45Hyperbeam后A0眩晕，原numTurns周期保持。Orb52–58HP、构造双HP抽样，25阈值只选择一次Stasis，70阈值选择仅给Automaton的格挡12，Beam8与Support禁三连。 |
| ApplyStasisAction/StasisPower | 抽牌堆非空就从抽牌堆选，否则弃牌堆；先稀有、罕见、普通，按原sourceId稳定排序，同ID保留原堆次序；各缺失桶不抽，实际选择抽一次cardRandom，所有桶缺失才整堆原序抽。扣押真实牌实例，归还使用相同UID和全部统计值，满手在死亡时即固定走弃牌；非满手构造受MasterReality升级，满手sameUUID弃牌不升级。无牌不抽随机，Boss死后清场不额外归还牌；回滚覆盖持牌表与原牌引用。 |

源编队全部读取`helpers/MonsterHelper.getEncounter`，逐一构造核对如下。其中哨卫、信徒、红蓝奴隶是固定源本来就使用的相同敌人，复用已审计策略；不会用它们替代其他未实现怪物。

| 来源池 | 已提供真实编组 |
| --- | --- |
| 5弱 | Spheric Guardian、Chosen、Shell Parasite、3 Byrds、2 Thieves |
| 8强 | Chosen and Byrds、Sentry and Sphere、Snake Plant、Snecko、Centurion and Healer、Cultist and Chosen、3 Cultists、Shelled Parasite and Fungi |
| 3精英 | Gremlin Leader、Slavers、Book of Stabbing |
| 3Boss | Automaton、Collector、Champ |

`abyss_act2_enemies`提供独立章节数据与严格允许列表；`Combat.new`只复制定义，不把新怪物塞进第一幕随机池。`Run.startRoomCombat`沿用已合入队列的事务；未知第二幕遭遇仍返回`act_content_unavailable`，不消费队列、不重抽。三Boss从33层现有Boss选择进入。正式Host/菜单和跨幕推进由TASK-63接线，不在本切片修改。

仍未实现并保留完整范围：Masked Bandits事件专属Bear、Pointy、Romeo；该编组仍被严格拒绝。Colosseum Slavers/Nobs所需的旧红蓝奴隶、GremlinNob与新增Taskmaster定义已存在，事件内部正式战斗事务和接线仍由事件切片处理。本片不宣称13事件完整、第二幕自然通关或任何平台验收。

验证：新增Lua先以`act_content_unavailable`、随后以缺失敌人失败，再逐片通过34组真实命令/算术回归。固定来源SHA256见`tests/fixtures/act2-enemy-source-lock.json`。执行`node --test tests/act2-enemies.test.mjs`、完整跨幕/队列向量、架构和固定Luacheck；原第一幕Combat23组、Guardian24组、CurlUp28组、Looter规则8组/运行/奖励5组、编队4组、queued-roll21组及queued-status20组均曾在相关切片后验证。组合检查和平台结果由父线程另外归档，不宣称同SHA完整check已通过。
