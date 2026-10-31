# M3 全33药水与随机流证据索引

结论：完整33项都有正常奖励/商店的可执行取得及消费入口；多数数值、目标、持续、回滚与组合有具体效果断言。**这不等于全效果或所有消费者随机序列都已独立核准。** 本轮只读索引，没有新增生产缺陷、重跑全套、修改冻结PR/代码/Backlog。

固定读取源码 `c3d2654beee31fdd011db0535228e063b657ab8a`；来源镜像 `aeubanks/sts@319009d5`。不是官方PC二进制认证。`matrix.json`含33项原序ID/Java类/源行号、生产effect/target、资源与重置、实际fixture断言摘录、自然证据逐动作及16类RNG owner的调用点/证明强度。源码中的旧目录productionWired/currentStatus是历史规划，不能当当前缺实现清单。运行定义中的Silent毒药不算旅行者canonical33。

这里的“有证据”指已读可执行断言；是否在最终候选通过，必须以最终CI实际分片结果确认。作者报告只作导航，没有作为独立验证结果引用。新cardRandom链的独审/运行证据与本轮静态索引分开。

## 33项逐件入口

| 原索引 | 本地ID ← 原版ID | 实际effect / 目标 | 具体效果断言 |
|---:|---|---|---|
| 0 | blood_potion ← BloodPotion | healPercent:20 / self | `tests/lua/potion_health.lua:6` |
| 1 | elixir ← ElixirPotion | exhaustMany:0 / self | `tests/lua/potion_choices.lua:17` |
| 2 | heart_of_iron ← HeartOfIron | gainStatus:6 / self | `tests/lua/potion_sustained.lua:10` |
| 3 | block_potion ← Block Potion | block:12 / self | `tests/lua/inventory.lua:77` |
| 4 | dexterity_potion ← Dexterity Potion | gainStatus:2 / self | `tests/lua/inventory.lua:80` |
| 5 | energy_potion ← Energy Potion | energy:2 / self | `tests/lua/inventory.lua:78` |
| 6 | explosive_potion ← Explosive Potion | damageAll:10 / enemy_all | `tests/lua/potion_explosive.lua:13` |
| 7 | fire_potion ← Fire Potion | damage:20 / enemy_one | `tests/lua/potion_reward_effects.lua:36` |
| 8 | strength_potion ← Strength Potion | gainStatus:2 / self | `tests/lua/inventory.lua:79` |
| 9 | swift_potion ← Swift Potion | draw:3 / self | `tests/lua/potion_basic_five_draw.lua:4` |
| 10 | weak_potion ← Weak Potion | applyStatus:3 / enemy_one | `tests/lua/potion_basic_five_status.lua:5` |
| 11 | fear_potion ← FearPotion | applyStatus:3 / enemy_one | `tests/lua/potion_basic_five_status.lua:5` |
| 12 | attack_potion ← AttackPotion | discover:1 / self | `tests/lua/potion_discovery.lua:5` |
| 13 | skill_potion ← SkillPotion | discover:1 / self | `tests/lua/potion_discovery.lua:5` |
| 14 | power_potion ← PowerPotion | discover:1 / self | `tests/lua/potion_discovery.lua:5` |
| 15 | colorless_potion ← ColorlessPotion | discover:1 / self | `tests/lua/potion_remaining_ui.lua:4` |
| 16 | flex_potion ← SteroidPotion | gainTemporaryStrength:5 / self | `tests/lua/potion_flex_speed.lua:42` |
| 17 | speed_potion ← SpeedPotion | gainTemporaryDexterity:5 / self | `tests/lua/potion_flex_speed.lua:42` |
| 18 | blessing_of_the_forge ← BlessingOfTheForge | upgradeHand / self | `tests/lua/potion_forge.lua:9` |
| 19 | regen_potion ← Regen Potion | gainStatus:5 / self | `tests/lua/inventory_parity.lua:155` |
| 20 | ancient_potion ← Ancient Potion | gainStatus:1 / self | `tests/lua/potion_basic_five_status.lua:25` |
| 21 | liquid_bronze ← LiquidBronze | gainStatus:3 / self | `tests/lua/potion_basic_five_status.lua:33` |
| 22 | gamblers_brew ← GamblersBrew | discardRedraw:0 / self | `tests/lua/potion_choices.lua:19` |
| 23 | essence_of_steel ← EssenceOfSteel | gainStatus:4 / self | `tests/lua/potion_sustained.lua:24` |
| 24 | duplication_potion ← DuplicationPotion | gainStatus:1 / self | `tests/lua/potion_duplication.lua:22` |
| 25 | distilled_chaos ← DistilledChaos | playTopCards:3 / self | `tests/lua/potion_chaos.lua:14` |
| 26 | liquid_memories ← LiquidMemories | discardToHand:1 / self | `tests/lua/potion_choices.lua:23` |
| 27 | cultist_potion ← CultistPotion | gainStatus:1 / self | `tests/lua/potion_sustained.lua:17` |
| 28 | fruit_juice ← Fruit Juice | increaseMaxHp:5 / self | `tests/lua/potion_health.lua:6` |
| 29 | snecko_oil ← SneckoOil | draw:5, randomizeHandCost:0 / self | `tests/lua/potion_snecko.lua:9` |
| 30 | fairy_in_a_bottle ← FairyPotion | fatalRevive:30 / self | `tests/lua/potion_fairy.lua:15` |
| 31 | smoke_bomb ← SmokeBomb | escape:0 / self | `tests/lua/potion_smoke.lua:7` |
| 32 | entropic_brew ← EntropicBrew | generatePotions:0 / self | `tests/lua/potion_entropic.lua:9` |

同一瓶的来源证明与效果证明分列在JSON中。例：普通33渠道测试确实逐瓶胜利→领奖→跨战斗→使用，但通常只核成功/库存消费。它不能替代Fire精确20、Explosive对两目标各减7且不触发CurlUp、Ritual首次回合顺序、Fairy最少1HP等具体断言。

## 有界、具体的剩余差集

1. **ColorlessPotion的输出合同。** 渠道测试会成功打开和选择；UI测试有说明文字。但本轮未找到直接针对无色药水核source-order去HEALING候选、retrieval额外生成、选定实例0费、满手溢出的结果断言。Attack/Skill/Power共享路径有相应效果断言，不能把无色那一行仅凭成功消费升级为逐效果实证。可用一个实际无色发现的完整源向量与公开选择结果补齐，不需重做33渠道。
2. **cardRandomRng剩余交点。** 新独立链已经逐次核Hand→Spoon→Branch→AttackDiscovery→Elixir→Snecko(noDraw)，含丢失retrieval消费的精确负变异。Chaos的现有目标RNG预期使用生产clone；Skill/Power/Colorless发现、Toolbox、Confusion/SneckoEye、随机目标/球、Stasis仍分别由现有fixture或局部源模型覆盖。需要的是明确消费者交点的完整bound/value/words/counter，不是任意153×33机械穷举。优先：Chaos预排全部目标→实际自动牌触发Hand/Spoon/Branch，及颜色发现候选源序差异。
3. **merchantRng完整消费。** 价格binary32四舍五入有独立向量；商店身份和失败不补货有事务断言。尚未定位从初始商店的售卖位、各价格抖动到Courier补货的完整独立逐调用流；正确价格公式不能证明实际抽样次数和顺序。
4. **cardRng完整身份插入。** 稀有度核心有228次wrapper/148次rarity独立预期，但原oracle明确省略每槽身份与重复重试。真实奖励/商店/Orrery/PrayerWheel/Neow与源池完整性已有可执行检查；仍不能据核心投影声称含身份插入的完整同流连续消费均已独立证明。
5. **事件与房间全消费者归账。** Act1初始HP/AI/misc交错、初始/重洗牌、普通/精英/Boss金币、药水共享流、遗物队列与部分事件均有强向量。其余事件misc消费者、后续AI/召唤以及Neow跨card/potion/relic来源不能仅凭各原语正确整体升级。JSON列出实际模块调用点，可按已存在域专项核闭每个交点；没有要求无限种子或所有可能路线穷举。
6. **153遗物效果仍须独立于定义数。** 130是旅行者五档来源身份，153含特殊/事件/其他职业运行定义。`relic_catalog_completeness.lua`核绑定与说明，分类hooks/Run/选择/营火等才核效果。当前索引只完成33药水逐件表，未以130/153数目替代逐遗物数值/对象/持续/先后断言。

## 16类随机owner与证据强度

| owner | 已有最强消费者证据 | 明确边界 |
|---|---|---|
| `run.cardRng` | EXACT_INDEPENDENT_TRACE · `tests/card-random-state.test.mjs` | 228 wrappers/148 rarities; intentionally omits interleaved identity selection |
| `run.encounters.monsterRng` | EXACT_INDEPENDENT_TRACE · `tests/encounter-queue.test.mjs` | source weighted queue/index/Java-shuffle vectors; default Boss history qualifier separate |
| `run.relicPool.rng` | EXACT_INDEPENDENT_TRACE · `tests/sts1-relic-pool-runtime.test.mjs` | host-Java randomLong seeds/permutations and independent JS queue interpretation |
| `run.shopRng.potion / combat.potionRng` | EXACT_INDEPENDENT_TRACE · `tests/sts1-potion-random.test.mjs` | nine source vectors; each attempt/bound/value/after words+counter |
| `run.shopRng.merchant` | INDEPENDENT_STATE_SUBSET · `tests/sts1-shop-price-lua-candidate.test.mjs` | independent inputs/rounding; explicitly not proof of merchant RNG sampling |
| `run.eventRng` | EXACT_INDEPENDENT_TRACE · `tests/event-random.test.mjs` | primitive conformance only |
| `run.miscRng / room.miscRng` | EXACT_INDEPENDENT_TRACE · `tests/encounter-runtime.test.mjs` | 126 room vectors; combat-gold separate exact source range/result/state |
| `run.treasureRng` | EXACT_INDEPENDENT_TRACE · `tests/combat-gold.test.mjs` | source bounds/value/full state; escape no draw |
| `map.topologyState/randomState/mapRng` | INDEPENDENT_STATE_SUBSET · `tests/sts1-map-topology-candidate.test.mjs` | fixed source graph/state contracts; graph match alone not all per-call stream proof |
| `combat.monsterHpRng` | EXACT_INDEPENDENT_TRACE · `tests/encounter-runtime.test.mjs` | full states and normalized exact range values |
| `combat.aiRng` | EXACT_INDEPENDENT_TRACE · `tests/encounter-runtime.test.mjs` | Act1 initialization exact; advanced JawHorde/Writhing/TimeEater etc use individual oracles |
| `combat.shuffleRng` | EXACT_INDEPENDENT_TRACE · `tests/combat-shuffle.test.mjs` | 35 initial+63 redraw independent vectors; raw randomLong/permutation/full states |
| `combat.cardRandomRng` | EXACT_INDEPENDENT_TRACE · `tests/card-random-chain.test.mjs` | five seeds; per-call bound/result/before-after words+counter, source IDs, exact lost-discovery-draw mutation |
| `event.neowRng` | EXACT_INDEPENDENT_TRACE · `tests/lua/neow_offers.lua` | fixed source vectors compare full after state/counter |
| `room.visualRng / cosmetic / external MathUtils adapter` | INDEPENDENT_STATE_SUBSET · `tests/encounter-runtime.test.mjs` | visual callback supplied controlled0; deliberately not original PC frame/global MathUtils parity |
| `run.seed / combat.seed legacy scalar LCG` | PRODUCTION_CLONE_OR_COUNTER · `tests/lua/combat_optional_potions.lua` | not canonical STS source stream and not a substitute for formal room owners |

JSON按消费者分别使用四档：独立逐调用完整轨迹、独立状态子集、生产clone/仅counter、未建立精确消费者证明。某个消费者强证明不自动提升整个owner。直接命名RNG调用点库存还列出源码文件/行；函数参数别名通过模块组索引，属于可审查的静态归账，不声称自动生成了完整调用图证明。视觉/global MathUtils与legacy scalar另列，不混入正式玩法流。

## 原AC能得出什么

| 条款 | 最终CI可证明的纯离线部分 | 本轮仍不能直接勾全的具体原因 |
|---|---|---|
| TASK-14.1 #5 | 33完整来源、目标策略、公开使用；每行所列精确数值/持续/限制断言；分类遗物效果既有证据 | 无色药水专门结果合同及逐遗物效果映射仍需归账；定义存在不是效果核准 |
| #7 | 叠加、Artifact前后、延迟债务顺序、Bark例外、生命/胜利/复活、重复输入、跨房间/跨幕potion owner守恒等实际列明交点 | Chaos等共享消费者交点的独立消费证据尚未建立，不能用成功渠道替代 |
| #6（已完成） | 全33正常奖励/商店来源且不缩池重抽；原概率与拒绝消费有独立oracle | 仍按其真实受控/起始牌战斗边界理解，不外推自然地图全件取得 |
| #10（已完成） | 不可领提示与拒绝原子性已有专门用例，完整资源/owner/RNG保持 | 保留原样，不因索引缺表重开已完成项 |
| TASK-16.1 #5 | Geo共享入口与现有75卡、药水、遗物专项中的实际数值/次序断言；新cardRandom跨域链 | 明确新增/跨域消费者合同按上述具体交点补，full-source未来职业不混为当前Geo准入 |
| #6 | 原语及多条域/同局链的精确流初始化、值、完整状态、回滚与提交 | merchant全调用、奖励身份交错、事件/AI/召唤剩余消费者和真实平台记录不能仅凭原语与局部向量关闭 |

## 自然与平台身份

JSON逐瓶列出实际自然driver库存新增/公开use动作，分别保留243ae1b旧3seed、c3d2654五seed、ca838ef修复seed17来源；不把合计观察冒充同一候选。未出现某瓶不表示不可得。旧243 seed2有两幕胜利，本轮C3四败一driver拒绝，修复ca838 seed17正常继续后败16层；它们不提供第二种完整自然通关。新Run构造隔离不等于Host胜败重开。

同候选官方导入、ready、PC与实体手机逐件日志/截图仍未由本索引获得。历史31a8f37火瓶实机作者记录仅作历史入口，没有当作本候选或本轮独立设备核验。未改变任一自然cohort产物。

## 后续小片（与索引候选分离）

`097f415`（基ca838ef）已新增Colorless公开效果及连续两瓶独立RNG证明，标记TEST_ADDED，未发现生产差异。正向/精准突变2/2、真实Git CRLF checkout1/1本地通过；独立复审/集成另行处理。它补的是上文第1项具体差集，不据此宣称c3冻结候选已有该测试或全RNG已核完。报告在 `/workspace/m3-colorless-proof/docs/reviews/M3-COLORLESS-POTION-SOURCE-20261031.md`。
