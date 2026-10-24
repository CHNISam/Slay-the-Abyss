# 战士完整药水池与实现分组

2026-10-25，基线 `eb4e8af`，复用 TASK-14.1 / TASK-13.1 / TASK-47。本片只交付[专用目录](../../data/catalogs/sts1-ironclad-potions.json)、独立抽取 oracle / 固定向量及[来源条目](../rules/evidence/sts1-ironclad-potion-pool-sources.json)，**没有接生产或将缺失药水放进合法可玩池**。生产 `data/potions.json`、Run、UI、地图与 Backlog 正文均未改。

固定社区镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方开源、正版 PC 二进制认证或 PC 实测。33 个药水类及 24 个池/商店/奖励/动作依赖文件已逐份读取并登记 SHA256 / Git blob；方法体只留在工作树 `.artifacts/potion-pool-source/`，未复制到交付代码或文档。另复核既有 AbstractPlayer 缓存的默认3槽及 Fairy 致死分支。

## 准确规模与原始顺序

[PotionHelper.getPotions(class,false)](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/PotionHelper.java#L79) 对 Ironclad 返回 **33 项：3 项职业专用先入池，再按声明顺序追加30共享项**。前3项是 BloodPotion、ElixirPotion、HeartOfIron；目录保留全部0..32原始索引。`getAll=true` 的42项用于跨职业枚举，不能当战士生产池。

| 稀有度 | 战士完整数量 | 稀有度概率 | 每个同类瓶子的条件边际概率 |
|---|---:|---:|---:|
| Common | 17 | 65% | 13/340 |
| Uncommon | 9 | 25% | 1/36 |
| Rare | 7 | 10% | 1/70 |

此固定源的 BlessingOfTheForge 为 **Common**，不能凭其他摘要改成 Uncommon。Silent 的 Poison/Cunning/Ghost、Defect 的 Focus/Capacity/Darkness、Watcher 的 Miracle/Stance/Ambrosia 共9项不属于战士 `false` 分支；排除依据是职业初始化，不是为当前执行器删池。当前只有6种战士瓶定义/基础效果；缺27种。已有 Poison 定义属 Silent，不算战士可获得项。

## 抽样与获取调用不能改成桶抽取

[AbstractDungeon.returnRandomPotion](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L805) 先用持久 `potionRng` 抽0..99决定稀有度，再反复从**完整33项原顺序**抽0..32，直到稀有度匹配。每个弃选都消费同一流；不是排序后的同稀有度桶一抽。`returnTotallyRandomPotion` 则只抽完整池索引，不抽稀有度。

`limited=true` 还会**无条件丢弃第一个候选**，随后拒绝稀有度不符及 Fruit Juice；普通 `false` 允许 Fruit Juice。Entropic Brew 战斗中调用 limited，战外调用普通版本；按 `potionSlots` 次生成，**不是按空槽数**。默认3槽，Potion Belt 扩容后须按实际槽数；Sacred Bark 改 getPotency，但此 use 循环不读 potency，不能臆造翻倍生成数。战内先生成候选再由 ObtainPotionAction 检查 Sozu，战外 Sozu 分支直接不生成。

[ShopScreen.initPotions](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/shop/ShopScreen.java#L359) 一次生成3瓶，未买也已消费选择流。选择和战后掉落、成功 Courier 补货、Entropic 创建都延续同一个 potionRng；价格抖动属于独立 merchantRng。[StorePotion.purchasePotion](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/shop/StorePotion.java#L74) 满槽/资金不足/Sozu不重抽，成功获得并付款后才按 Courier 补货。

[AbstractRoom.addPotionToRewards](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L582) 用同流先抽掉落：初始40%，成功修正-10，失败+10，不截断。普通全员逃跑为0，White Beast Statue后置覆盖为100，奖励已有至少4项再覆盖为0；保证/抑制仍抽一次。普通/精英/Boss/事件战斗的上下文与优先序保留在目录。奖励点击已有选定瓶，不重抽；Sozu消耗奖励条目但不获得，满槽则保留条目。主动用瓶按 use→持有遗物 onUsePotion→销毁来源槽；Fairy 走致死自动分支。

## 27项缺失内容可按依赖拆分

| 组 | 数量 | 内容与关键依赖 |
|---|---:|---|
| 直接伤害/抽牌/增减益 | 8 | Explosive、Swift、Weak、Fear、Flex、Speed、Ancient、LiquidBronze；补库存AoE、独立ApplyPower顺序、LoseDexterity与Artifact边界。Explosive是null-owner NORMAL矩阵，不能套Fire的THORNS路径。 |
| 持续能力 | 3 | HeartOfIron / EssenceOfSteel / Cultist；Metallicize、PlatedArmor在preEndTurnCards加盾，玩家Ritual与敌方钩子分开。 |
| 生命与复活 | 3 | Blood / Fruit / Fairy；战外使用、Run与Combat最大生命同步、致死时Fairy先于LizardTail且受MarkOfBloom约束。 |
| 手牌/弃牌选择 | 4 | Elixir / Gambler / Blessing / LiquidMemories；任意张选择、消耗/丢弃触发、战斗实例升级、弃牌回手及本回合0费。 |
| 三选一生成卡 | 4 | Attack / Skill / Power / Colorless；完整源卡池去HEALING，3个不同ID，用cardRandomRng，选定实例本回合0费及手牌溢出。不能从现有30卡子集重新分概率。 |
| 自动打牌/随机费 | 2 | DistilledChaos / Snecko；牌队列、随机目标、空堆洗牌、cost及costForTurn。Snecko对非负基础费逐张抽0..3，不只改当前回合费用。 |
| 重复打牌 | 1 | Duplication；复制实例入牌队列、purge防递归、energyOnUse与源轮末减层，不用一个简化布尔标记代替。 |
| 玩家逃跑 | 1 | Smoke；smoked房间不领奖，拒Boss或BackAttack，恢复地图/库存身份。 |
| 再生成药水 | 1 | Entropic；完整有序池、limited额外消费、可变容量、Sozu、溢出时仍已消费的生成次数。 |

每瓶的基础量、目标、可用范围、动作/能力依赖和源行号均在目录；这是实现拆分输入，不是已通过的效果验收。DiscoveryAction 的 update 调用还可能产生额外 cardRandomRng 消费，药水池向量不认证其帧时序。完整遗物池带来的 Sacred Bark / Potion Belt 等组合也须继续验。

## 验证边界

独立 Python oracle 不读目录 JSON、不调用生产 Lua；手写33项源顺序与分类，输出9个 signed64 seed 的连续商店3瓶→普通/精英/Boss/事件掉落→Courier→抑制/保证掉落→战内/战外Entropic→显式稀有度/均匀抽样向量。Lua 解释器读取目录并使用现有 STS 原语，逐次核对候选索引、拒绝轨迹、modifier、双word/counter；另测64/65、89/90、初样浪费、Fruit及全部33个均匀索引。初始测试真实因目录缺失而失败，完成后4项定向测试通过，日志见[机读验证记录](../rules/evidence/sts1-ironclad-potion-pool-verification.json)。

这些是**完整原池参考**，不是现有 Run 已采用完整池、效果已实现或整局同seed认证。没有运行 full check、GUI、平台编译/导入/实机、push 或 merge；任务状态与验收项不改。下一步应按上述组逐项实现并把同一完整目录接入生产，不沿用受限桶或缺口占位作为最终规则。
