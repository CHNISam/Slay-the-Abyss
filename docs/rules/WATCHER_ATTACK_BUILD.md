# 观者攻击与衍生牌构筑切片

仅添加独立`abyss_watcher_attack_cards.withCards(data)`，不改正式牌池或宣称全职业完成。15张紫色牌与洞见、安全、惩罚3张无色特殊牌使用固定319009源码核实后的数值；现有公开镜像不是官方开源、正版二进制认证或本轮原版实测。中文名为本项目显示标签；英文`sts_name`与`sourceId`保留来源身份，未核对原版简体本地化资源。

| 牌 | 稀有度/费用 | 基础 → 升级 |
| --- | --- | --- |
| Consecrate 奉献 | 普通/0 | 全体5 → 8伤害 |
| Bowling Bash 保龄猛击 | 普通/1 | 每名存活敌人令同一目标受7 → 10伤害一次 |
| Flying Sleeves 飞袖 | 普通/1 | 保留，4 → 6伤害两次 |
| Follow-Up 追击 | 普通/1 | 7 → 11伤害；前张攻击则能量+1 |
| Crush Joints 碎关节 | 普通/1 | 8 → 10伤害；前张技能则易伤1 → 2 |
| Sash Whip 绸带抽打 | 普通/1 | 8 → 10伤害；前张攻击则虚弱1 → 2 |
| Empty Mind 净空 | 罕见/1 | 先抽2 → 3，再退出姿态 |
| Evaluate 评估 | 普通/1 | 格挡6 → 10；未升级洞见随机放入抽牌堆 |
| Halt 止步 | 普通/0 | 格挡3 → 4；愤怒额外9 → 14 |
| Carve Reality 雕琢现实 | 罕见/1 | 6 → 10伤害，未升级惩罚加入手牌 |
| Deceive Reality 欺瞒现实 | 罕见/1 | 格挡4 → 7，未升级安全加入手牌 |
| Sanctity 圣洁 | 罕见/1 | 格挡6 → 9，前张技能则抽2 |
| Signature Move 招牌技 | 罕见/2 | 无其他手牌攻击时可用；30 → 40伤害 |
| Scrawl 潦草急就 | 稀有/1 → 0 | 抽到10张手牌，消耗 |
| Brilliance 光辉 | 稀有/1 | 12 → 16基础伤害，加本战累计获得真言 |
| Insight 洞见 | 特殊/0 | 保留，抽2 → 3，消耗 |
| Safety 安全 | 特殊/1 | 保留，格挡12 → 16，消耗 |
| Smite 惩罚 | 特殊/1 | 保留，12 → 16伤害，消耗 |

## 接入边界与结算顺序

共享Combat负责真正执行、目标检查、动作队列、引用图事务和CardHistory。模块仅返回独立数据，不保存函数，不另造战斗引擎。未知费用叠加沿用共享combatCost/turnCost ABI，不自行覆盖或猜测；Corruption照技能合法性费用门槛与实际免费支付/消耗规则处理。

* `adaptDefinition(state,instance,definition)`放在升级后、普通伤害修饰前，仅将`state.mantraGained`加到Brilliance伤害基础一次，不能改成固定伤害，也不能累加到目录。本战累计计数的时点由既有Mantra构造器负责。源`use`中先改`damage`随后`calculateCardDamage`覆盖，不能据前一句再次加真言。
* `prepareEffect(state,effect)`在整张牌use动作构造时调用，返回密集effects数组。`bowlingBash`按当时存活未逃离敌人数展开独立damage，不能在首击后重新计数，也不能把次数直接乘伤害；每击分别处理力量、格挡、反击等。其目标仍是原始选定目标。
* Halt的`{op='halt',value=3/4,wrathValue=9/14}`在prepare时通过真实`Actors.blockAmount`分别计算两份Block，记录`prepared=true`。执行时再读取Wrath并合并成**一次**固定GainBlock。例：未升级、敏捷2、脆弱，floor((3+2)*.75)+floor((9+2)*.75)=3+8=11；合计基础愤怒12/18、敏捷两次，不能先合计再一次修饰。格挡总量上限由共享一次GainBlock处理。
* `planEffect(state,effect)`返回应压TOP的actions，数组按执行先后排列，宿主逆序pushTop。支持prepared Halt、`drawToHandSize(value=10)`以及`previousCardType(cardType,effect)`。源四条件动作执行时检查`cardsPlayedThisCombat[size-2].type`，本张已经入史；历史跨回合保留。此处约定`state.cardsPlayedThisCombat`为纯`{type=...}`数组、含当前成功使用的牌。首张无前张。Follow-Up在伤害之后才检查并TOP加能量；Crush/Sash在伤害后TOP施加状态，所以不倒用易伤增强该次伤害；Sanctity先Block再判断TOP抽牌。
* `canUse(state,instance,definition)`补充`requiresNoOtherAttack=true`的Signature Move检查，按实时手牌实例UID排除自身。另一张同名攻击仍阻挡；不可只检查牌名，失败不得消费能量/移牌/增加历史。
* Scrawl执行时算`10-#hand`，当前使用牌已离手；正数才TOP draw。使用真实Draw处理NoDraw、空堆、洗牌与手牌容量，不承诺必抽满。

共享新增生成动作`{op='makeTempCard',cardId,pile,value=1,upgraded=false,randomSpot=true仅draw}`必须生成新唯一UID且不改永久牌组。Carve/Deceive升级不升级产物；满手时产物进弃牌堆。Evaluate是随机**插入**，不重洗已有抽牌堆：空堆直接append、不调用cardRandomRng；非空n调用cardRandomRng.random(n-1)，Java索引0..n-1等价Lua插入1..n，排除新尾top，所以已有top保持不变。这个RNG是独立cardRandom流，不借shuffle流；随机数调用/primitive须纳入失败事务。源MasterReality会升级产物，本切片未实现该Power，宿主必须对非零master_reality明确拒绝，不能静默生成未升级牌。无色特殊产物不进入紫色普通奖励池。

终局由共享队列clearPostCombatActions策略负责：保留普通Damage与GainBlock/UseCard必要收尾，取消Follow-Up能量、条件状态/抽牌、生成牌及抽牌。玩家死亡继续停止。新的条件外壳不是Damage，不应仅因内部effect是Damage/Block就绕过终局规则。

## 验证状态

`node scripts/test-lua.mjs tests/lua/watcher_attack_build.lua`在根线程sts-triggers共享接线基线上23组通过（约2.5秒）。测试使用真实Combat.play/endTurn：覆盖数据隔离、升级、每击伤害、前张类型/跨回合历史、终局退款取消、Calm退出/NoDraw、Halt双敏捷与脆弱逐份取整、Signature Move失败不消费、Scrawl满手、真言一次叠加、生成牌保留/消耗、随机插入保留原top。空抽牌堆不耗cardRandomRng，单牌堆仍耗一次；另在真实RNG完成后注入错误，验证格挡、费用、UID、历史、queue、事件及RNG primitive全部恢复原引用与值，再正常成功使用。不替换战斗引擎，未跑全量或平台实机。

## 固定来源

逐份检查构造、use、upgrade以及条件动作update/随机插入链；独立写卡牌定义与计划器，没有复制Java方法体。以下SHA256是原始下载字节；每行链接固定到[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，不是浮动master。

| 源文件 | SHA256 |
| --- | --- |
| [actions/common/MakeTempCardInDrawPileAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDrawPileAction.java) | `c00b2da9c82d6e5fed1f638312a2af46dcd586bcd76e963f859e4417629ac2fe` |
| [actions/common/MakeTempCardInHandAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInHandAction.java) | `b089bb6fd688ffdd48ae9def57751f972429cad63f85ec80ee3f90593d5bbe25` |
| [actions/unique/ExpertiseAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/ExpertiseAction.java) | `94569a706f2df629630c22626fb142ab2f3d7c828cc982201ed96256733fa879` |
| [actions/watcher/CrushJointsAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/CrushJointsAction.java) | `5af0ac72d3e3fe4b0b83508695ab301d25f9cddde91bdb77d4c43f343283f82e` |
| [actions/watcher/FollowUpAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/FollowUpAction.java) | `c4bdfea34fb8ed2c1177ad2e9a59a539177843d1a61e8348c66f4b1c30f3a88a` |
| [actions/watcher/HaltAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/HaltAction.java) | `9e9fb578d5b122d020e48862bc08b607c979663c99189ae5c8ff3196f920d3af` |
| [actions/watcher/HeadStompAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/HeadStompAction.java) | `317a0791b810a6c1a43f75f483dda0a9de7a6bdb0aa441c24795d126ea5e6edd` |
| [actions/watcher/SanctityAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/SanctityAction.java) | `89d4e3c06589756546f4ff8a02267eac6db754ada23ab959ec18454e4aaceeb0` |
| [cards/AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [cards/CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [cards/purple/BowlingBash.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/BowlingBash.java) | `f08cffb3a0547a6118e0fe9ec54156d7f155a792a891091b2293d1c7d3265273` |
| [cards/purple/Brilliance.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Brilliance.java) | `6ce900f30a94f7c99cf44fc022f2c2e5da5bda4c35638d00f304e4a531150a26` |
| [cards/purple/CarveReality.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/CarveReality.java) | `6b236267fc2a8bb9d124d9d7a498b36014e5d541e199b76b519eee972fc9ffe1` |
| [cards/purple/Consecrate.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Consecrate.java) | `d6b4546c5c68883b5e636de71768e4d789f565327b8904019d35aa13727c0d3f` |
| [cards/purple/CrushJoints.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/CrushJoints.java) | `0833dafe32958546d6ec8518c60ea2a334054923e566f585152d9f95c98cc699` |
| [cards/purple/DeceiveReality.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/DeceiveReality.java) | `9311adb5ee985eb182cdbcbeb806579bb61f4ee2c3f5a079c064e3e5758382a3` |
| [cards/purple/EmptyMind.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/EmptyMind.java) | `d1e13846796e6186debb1f9e5be8f7e8944348c60971521d4015b463bf71f295` |
| [cards/purple/Evaluate.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Evaluate.java) | `36bb677c785604bf580f5925d49ab5a7b146aabdee6717303a591436f1a7cfeb` |
| [cards/purple/FlyingSleeves.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/FlyingSleeves.java) | `75aa64a9975c6341b9a1c02de49c7237190745b376b407f394b5ead9a34e3297` |
| [cards/purple/FollowUp.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/FollowUp.java) | `fb070528971876dcb2309b003d8b7b04b818d95c754156c00af419c0a4f30247` |
| [cards/purple/Halt.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Halt.java) | `f8a03b284532f7f9623ff8d49d34f2c41cfe5c0d525b9925e4b886de67772b69` |
| [cards/purple/Sanctity.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Sanctity.java) | `3e6252f658e2835881a9a7dc3897bef167930bb8e4dd61dc0c539ea7b37a0295` |
| [cards/purple/SashWhip.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/SashWhip.java) | `c74e6f72d6fe064ee04e13021b3bbfafce8afaf625e5607c046b26ae94cb930c` |
| [cards/purple/Scrawl.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/Scrawl.java) | `f746b007a321b3ad91746469d1e3bd2302c52aaa1553cea6fd8d3c0f06acf7f3` |
| [cards/purple/SignatureMove.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/SignatureMove.java) | `fc9cfb7b9e7d481d7740a153f446dd7df9198bc064d35b02e7099d6d16d0b32d` |
| [cards/tempCards/Insight.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/Insight.java) | `0bc12e832eb57dd7c969da15c0f3c45b9d1d91ab4c768179806669c43b637008` |
| [cards/tempCards/Safety.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/Safety.java) | `58dcd355ff1ac4c0a69ba1ab81663aed91dd0a7b4cf1aa09c55104449ee290c2` |
| [cards/tempCards/Smite.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/tempCards/Smite.java) | `849c5aa27648f5c6a6fc361e6ef48b25bc528e9df7652d49ffcfb5385241010e` |
| [vfx/cardManip/ShowCardAndAddToDrawPileEffect.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/cardManip/ShowCardAndAddToDrawPileEffect.java) | `d2b573fb3488c551a4039e68a5c487b76a60fdbcfecaf5bf7254ed9bc8417433` |
| [core/AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java) | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
