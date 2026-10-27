# 天罚（Nemesis）A0 独立切片

只接通原第三幕精英队列中已有的 `Nemesis`，不改队列权重、排重、随机池或奖励管理器。`Giant Head` 与 `Reptomancer` 的注册归各自切片；后续集成须合并各自早期 resolve 分支，不互相覆盖。

固定行为资料为第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，通过 GitHub connector 定向读取19份文件并复用已验证缓存6份；没有下载 ZIP。原始 UTF-8 内容按 Git blob 校验，25份逐字节 SHA256 和路径见 [来源锁](../../tests/fixtures/nemesis-source-lock.json)。没有把 Java 原文复制进产品，也没有运行认证原作 PC 二进制。

| 来源方法 | 本片合同 |
| --- | --- |
| Nemesis constructor、AbstractMonster.setHp | A0 HP185；`setHp(185,185)` 仍消费一次 monsterHpRng。位置0,0；ELITE。动画和音效的 MathUtils 不消费游戏随机流。 |
| Nemesis.getMove | 每次先消费0–99主roll，再将冷却减1（开场0→−1）。首招小于50选6×3，否则塞3 Burn，无开场 Scythe。以后小于30优先合法45伤害 Scythe，小于65优先Fire，其余优先Burn；严格保留 lastMove/lastTwoMoves 与条件 Boolean 分支。选Scythe置冷却2；Boolean 的短路顺序不可按最终招式猜测省略。 |
| Nemesis.takeTurn | 每次Fire为三个独立普通DamageAction，各次受力量/虚弱/易伤、格挡、反伤与死亡取消影响。Burn往弃牌堆放3张独立、未升级状态牌，不是Artifact可挡的Power。动作排好时判断是否缺Intangible；缺时排ApplyPower，之后RollMove。 |
| IntangiblePower、IntangiblePlayerPower | 怪物 `Intangible` 与玩家 `IntangiblePlayer` 是不同Power。怪物priority75，第一次owner-end只清justApplied，下一次减1/移除；怪物组全部行动后、玩家atEndOfRound之前执行。`nemesis_intangible` 独立ID避免修改玩家现有轮末寿命。自然表现为首次行动后有、第二次行动后无，交替出现。 |
| Nemesis.damage、DamageInfo、AbstractMonster.damage、Boot | 所有正info.output先被Nemesis压到1，再扣格挡；THORNS/HP_LOSS/poison同样受限。0伤害不变；只处理受击目标。Boot随后可把玩家普通攻击的正未格挡伤害提高到5，不把Intangible当作最终HP硬上限。 |
| MakeTempCardInDiscardAction、ShowCardAndAddToDiscardEffect、Burn | Burn不消耗ai/cardRandom/shuffle，插入discard顶部，STATUS不受MasterReality升级。源动作数量ABI沿用已有0–5上限。真实Burn之后按普通抽牌/轮末THORNS2处理；不改永久牌组。 |
| RollMoveAction、DamageAction、ApplyPowerAction | 致死反伤后取消后续普通攻击、死目标不获Intangible；有队友时原已排RollMove仍执行，最后敌人死亡时按现有清队列收口。普通精英奖励沿用现有源金25–35、遗物、卡牌和药水通道，不自动领取。 |

独立 [Python模型](../../tools/oracles/sts1_nemesis.py) 不读取生产Lua/数据，生成 [208组边界和4×12行动向量](../../tests/fixtures/act3-nemesis-vectors.lua)。Boolean用独立64位原语低位，而非有界整数抽样替代。长算式fixture显式使用1000HP与65张不打出的Strike，令12轮内生成Burn留在弃牌堆以独立观察AI/伤害；这不是自然牌组、注入Run或连续通关证据。独立原源队列投影另确认直接第三幕seed1/4的首精英为Nemesis；旧Orb的“未实现精英”负例改用仍为Reptomancer的seed42，没有删除拒绝断言。

定向测试覆盖固定HP一次抽样、所有条件分支消费、完整HP/AI words/counter、连击逐段、属性修正与反伤取消、怪物/玩家Power边界、格挡/毒/THORNS/HP损失/Boot、零层Power成员、Burn实例/UID/目的地/Artifact/抽取后灼伤、真实Run队列及普通精英奖励、晚失败保留原table身份的事务回滚。Host控件读取“天罚185/185”“6×3”“3张灼伤→弃牌堆”“无实体”，不新增布局或UI规则。

当前证据只覆盖离线切片。完整Quality、精确远端SHA CI、正式导入、实机UI、自然获取及四职业跨幕通关未在本片执行，不据此宣称完整M3/原PC一致/平台验收。
