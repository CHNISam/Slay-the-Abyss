# 猎人基础攻击与跨回合资源

独立追加14张固定源卡牌，已存在的运行ID保持原定义，不重复注册。只使用已有基础操作和交给共享核心的少量条件/跨回合接口；不实现After Image、A Thousand Cuts或Envenom，不覆盖另一个触发器任务。

新增卡定义均提供中文name与英文sts_name/sourceId；中文默认标签是项目编写的可读名称，不声称逐字认证原版中文译名，正式表现层可按既定美术文案覆盖。GrandFinale明确标记experimental，进入已有高级条件门禁后才检查draw_pile_empty，拒绝码为requires_empty_draw_pile。

## 固定来源

[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，声明V2.3.4 / 2022-12-18。社区反编译镜像，非官方源码或认证PC二进制；仅核对事实并独立编写，没有保存原方法体。

| 类名／运行ID | 费用、类型、稀有度 | 基础及升级行为 |
| --- | --- | --- |
| Bane / bane | 1攻击，普通 | 7/10伤害后，若目标在BaneAction执行时有毒，再造成相同伤害 |
| Slice / slice | 0攻击，普通 | 6/9伤害 |
| SuckerPunch / sucker_punch | 1攻击，普通 | 先7/9伤害，再Weak1/2 |
| PoisonedStab / poisoned_stab | 1攻击，普通 | 先6/8伤害，再Poison3/4 |
| RiddleWithHoles / riddle_with_holes | 2攻击，罕见 | 每次3/4伤害，共5次 |
| Backstab / backstab | 0攻击，罕见 | 11/15伤害；基础、升级均Innate且消耗 |
| Adrenaline / adrenaline | 0技能，稀有 | 先能量1/2，再抽2；均消耗 |
| Deflect / deflect | 0技能，普通 | 格挡4/7 |
| Caltrops / caltrops | 1能力，罕见 | 自身Thorns3/5；离开牌堆，不是消耗 |
| FlyingKnee / flying_knee | 1攻击，普通 | 先8/11伤害，再获得Energized1 |
| Outmaneuver / outmaneuver | 1技能，普通 | 获得Energized2/3 |
| DodgeAndRoll / dodge_and_roll | 1技能，普通 | 当下格挡4/6，将本次计算后的this.block存为下回合格挡 |
| GrandFinale / grand_finale | 0攻击，稀有 | 抽牌堆必须为空才可使用，50/60全体伤害 |
| HeelHook / heel_hook | 1攻击，罕见 | 5/8伤害；动作执行时先查Weak，实际伤害后获得1能量并抽1 |

## 条件与快照时点

BaneAction属于DAMAGE动作，在第一段伤害及其队头反应后动态查Poison。新Envenom若在第一击造成HP损失后施毒，会使第二击条件成立；不能在整牌点击时预读一次有无毒。第二段DamageInfo本身仍来自出牌时原伤害快照，不应被第一击后意外改变的力量重新计算。共享ABI为damage后conditional target_poison、then damage。

HeelHookAction先根据Weak排Draw与GainEnergy到TOP，再把Damage排到更前。因此用专属 `heelHook` op捕获Weak条件和伤害，不能用普通“伤害后才读取Weak”的条件。真实顺序是伤害→能量1→抽1；末敌被击杀或攻击者死亡时后续能量/抽牌取消。NoDraw只拦抽牌，不取消能量。后续不同伤害类型的触发顺序由共享队列/触发器任务统一处理。

GrandFinale的draw_pile_empty是canUse前置：抽牌堆有牌时必须在扣费、移动、随机消费前拒绝；不能等打出后当成0伤害。抽牌堆空但弃牌堆非空仍合法，不要求所有可抽卡均为空。

## 跨回合能力的时点与API

`nextEnergy`使用energized状态。EnergizedPower构造和叠加均cap999；不会立即改变当回合能量。普通下一回合的确切链为：

1. GameActionManager调用起始powers，NextTurnBlock、Infinite Blades等把各自动作入队。
2. 构造DrawCardAction(...,true)，其构造又创建PlayerTurnEffect；PlayerTurnEffect构造立即energy.recharge并调用所有power.onEnergyRecharge。
3. Energized的onEnergyRecharge直接增加能量，并把RemoveSpecificPowerAction入BOTTOM。此前已经排好的起始能力动作随后执行，移除Energized也在普通Draw前完成。
4. 执行普通抽牌；post-draw能力如Noxious Fumes继续在抽牌后。

共享入口需要基础能量重置后加Energized、普通抽牌前完成移除，不可在回合结束、抽牌后或每次技能使用时支付。辅助 `onEnergyRecharge(state)`只加能量，不提前抹掉power；`removeNextEnergy(state)`供正确移除位置调用。现片不包含Ice Cream/Conserve等保能量交互或任意power.onEnergyRecharge次序。

`nextBlock`使用next_turn_block状态。Dodge and Roll的NextTurnBlockPower构造量为**出牌时this.block**，已考虑当时Dexterity/Frail。下一回合atStartOfTurn把固定GainBlock(amount)及移除动作入队。GainBlockAction→AbstractCreature.addBlock不会再加一次Dexterity/Frail；仍保留其他onGainedBlock类观察者的共享处理。比如当下4基础+2敏捷得到6，之后再获得3敏捷，下一回合仍只得6，不是9或11。

辅助 `applyNextBlock(state,amount)`的输入必须是出牌时已修正的快照，不可把未修正的基础值传入；`preDrawBlock(state,api)`调用共享 `api.block(...,true)`固定格挡后移除。即便amount为0，power仍需按presence~=nil处理一次并移除，不能用amount>0代替是否存在。

`applyNextEnergy`采用cap后的状态增量调用Actor，当前片没有外部onApplyPower观察者；若未来观察原始incoming数值，须恢复完整Power构造/stack observer语义，不能以相同最终数值当成全交互认证。

共享函数只通过调用栈接收api，没有函数存进state。所有计数、能量、状态及快照须由共享整牌/整回合事务保护；本片不创建另一套回合引擎。

## SHA256

以下为本轮HTTPS读取固定提交完整原文件的字节哈希：

| cards/green/文件 | SHA256 |
| --- | --- |
| Bane.java | `8932f9ec4388e5d5c6f0f9a1acd39fdf8a5fc8dc1f7309b0605a21760b5e69e8` |
| Slice.java | `14e2d95e608c74c364bc0128f35d5da547b38a96777b515de0b2c666ede2240b` |
| SuckerPunch.java | `ada9152070432b713f8171563f53e51ba9427bf3d0ce7bb0caadd28fb246217e` |
| PoisonedStab.java | `642d7aa0463679c8d366d1926ac0a9dc4258b492b676442478cfb9707735bb30` |
| RiddleWithHoles.java | `e030c23931b82a3c181ed388ceb617145b6aa1b8bc50e071a63cbb67e2e1ae18` |
| Backstab.java | `6fb74d1e05ba3eb2fdf31cf6876c585894397305e8658fc61ecdd2a3e65c7bd3` |
| Adrenaline.java | `f6e3c82eaeb23b3655b570609263d29c4c05066aa09ae22e0c26dfa2db02f6df` |
| Deflect.java | `f4b3a3e048dd876e7295df283b333a6c99cc89d2d2d491f06f8ba86d66141b02` |
| Caltrops.java | `3935036b01be2a3ee2d065c4444939b1491f2094cecd27e49754602f8e545d00` |
| FlyingKnee.java | `6e1623d2785b7fea2621b2b5a59cc9322653324ca6b21b540d6102eb172bd360` |
| Outmaneuver.java | `110553631eeb395fbf5674151efb2866bb747c35b33aa616b8f49ccf97120ecd` |
| DodgeAndRoll.java | `451dc75112b2df032111087a9b0058b5e3e5ebe2ac29ec6945a7991f50971dd1` |
| GrandFinale.java | `3e81c10b12e1aeb4f1b47539aedf6c5c02562ce23595fcedc78af8c92b180b38` |
| HeelHook.java | `14cc0a3f6fbb1aad4760c6b8eba51b0811f443afbaf6f2179d63e599f63fca02` |

| 辅助方法链文件 | SHA256 |
| --- | --- |
| actions/unique/BaneAction.java | `44b3a25a3e07e1a6914700c6b62fae3c7c2bfc633ce6b917cb04b787d3f2831b` |
| actions/unique/HeelHookAction.java | `27da00bdc3df94b1db68eaca1765d5f00f0c30082cd03709c9e683c35ad312ef` |
| powers/EnergizedPower.java | `e827aec6f7a1561fa4c595d289713251f1e0f4e29d798d0b203c2e1b887859d0` |
| powers/NextTurnBlockPower.java | `4e7e395a226e445681515dd3c69e612886f39d7d7acba7c4632dfcbcc9a51e49` |
| powers/ThornsPower.java | `78ce7c63874a3539f03c50a9cdfdf8bcfba7b47e73bce18c10672e5bad3ae87a` |
| actions/common/GainBlockAction.java | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| core/AbstractCreature.java | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| core/EnergyManager.java | `82c676fdd86d3b409cd7bc38c294e65ee6c2b3a2bea5bce38a8bf98d56dd4383` |
| actions/common/DrawCardAction.java | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| vfx/PlayerTurnEffect.java | `014ddd04c526de9d81b15a4080f80cf0c04e0f3243b60fcb208cdaab9ced4d0d` |

## 当前验证状态

`node scripts/test-lua.mjs tests/lua/silent_attack_build.lua`首次私树基线运行前20组通过，第21个真实Bane因缺target_poison ABI明确失败，退出码1。主线程接入共享后重新同步，当前39组全部通过，退出码0；没有mock机制、静默跳过或修改共享核心来制造成功。

真实通过Bane有毒/无毒、HeelHook Weak/非Weak/NoDraw/末敌、Flying Knee延后能量与末敌取消、Outmaneuver一次性跨回合、Dodge后打Footwork仍按原快照得盾、GrandFinale前置拒绝无副作用及准确requires_empty_draw_pile错误码、弃牌非空仍可用。

另有3个真实Envenom+Bane组合：目标初始无毒时第一击造成伤害并被Envenom施毒，Bane第二击随之成立；第一份毒被Artifact挡住时只有一击；第一击被完全格挡而Envenom不触发时也只有一击。这3例使用其他任务的真实触发器模块及真实出牌，不重复实现Envenom，也没有注入首击毒层来伪造组合。

还没有本批14牌的自然奖励获取、平台导入或客户端验收证据。卡牌机制测试里的300生命敌人为明确隔离夹具，不冒充自然流程或完整通关。
