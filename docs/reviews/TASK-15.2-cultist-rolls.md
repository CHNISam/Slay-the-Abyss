# TASK-15.2 · 祈火徒固定选招的随机消费

## 有限生产问题

基线 `20a04189d0765fd83b3a90e48da12a8c15ef3aab` 已实现 Cultist 的 HP48–54、仪式3、基础攻击6与仪式轮末时序，但 `ritual_then_attack` 从不请求 AI 随机数。固定动作并不意味着没有抽样：继承初始化和每次行动结束均有一次主选招请求。

本切片只做三处生产修改：

- `data/enemies.json` 的 Cultist AI 增加 `rollRange: 100`。
- `scripts/validate-data.mjs` 接受并要求该字段为 1–65536 的整数，沿用现有选招范围契约。
- `src/lua/abyss_enemy_ai.lua` 在初始化、每次 Ritual/Strike 后请求一次该范围；将已核实的 `ritual_then_attack` 加入现有死后排队 RollMove 白名单。

结果仍被忽略，首次选择 Ritual，此后固定 Strike。没有改伤害、HP、Ritual增长、Combat调度、状态算法或其它敌人策略；不为音效/对话/动画的 MathUtils 随机数增加游戏 AI 请求。

## 固定来源与认证边界

2026-10-23 UTC 只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。其版本字段自称 `[V2.3.4] (12-18-2022)` / `2022-12-18`；未与正版 PC JAR/hash 认证，不是官方开源、原作录像或本轮 PC 观察。仅据方法调用关系独立实现行为，没有复制或编译上游实现。

| 固定文件 | 方法事实 | Git blob |
| --- | --- | --- |
| [Cultist.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Cultist.java) | getMove 忽略输入，只区分 firstMove；takeTurn 的 Ritual 和 Strike 分支之后均无条件加入 RollMoveAction | `b2a203b035502dac149ced1d7dd48a8e577a61c6` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | init 调用 rollMove；rollMove 请求 aiRng.random(99) | `4784e38e7afff5980736e2b5c718e62a0c838c47` |
| [Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | random(int) 计数并调用 nextInt(range+1)，原请求为闭区间0–99 | `c4b71d5645688f6e764c46c593223eb91a5249bc` |
| [RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | update 无owner死亡保护，直接调用monster.rollMove | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` |
| [ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | 反伤加入队首，先于原队尾RollMove执行 | `e898e2f525a6eb49664eadb847dacb681f2931fe` |
| [DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | 伤害后仅全部怪物基本死亡才调用clearPostCombatActions | `ea89aeab60af8a7c297495de3cd8eb82d7130232` |
| [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | 清理仅保留指定Heal/GainBlock/UseCard和DAMAGE；RollMove不在保留名单；先排空动作再执行下个怪物 | `1662da8de2aeb42044b385f03d0c801750904b13` |
| [MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | 基本死亡按isDying/isEscaping判断 | `7096970a151840489a3fba89806e6391e0d82d76` |
| [CardCrawlGame.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java) | 版本声明，不等于正版认证 | `6f15eb15977a40bcb6e95598513a3073310eacd3` |

Cultist读取内容按Git blob算法复算吻合，UTF-8 SHA256为 `93e6404234a9c57f794c1f98f7943b60c62e66c464dd19d7579913fd75ad7f4f`。队列边界沿用已合并的[死后排队选招账本](../rules/QUEUED_ENEMY_ROLL_AFTER_DEATH.md)，本次重新读取上表链路而非把所有AI一概加入白名单。

## 确定预期与停止边界

| 输入情形 | 预期 |
| --- | --- |
| 开场主roll为0或99 | 均消费一次，选择Ritual |
| 正常完成Ritual或Strike | 每次消费一次，后续意图为Strike |
| 攻击被反伤杀死，仍有活队友 | 消费该次已排队roll，随后队友行动；死Cultist不增长力量或再行动 |
| 最后敌人被反伤杀死 | 先清队列，不消费该次roll |
| takeTurn之前中毒死或被玩家击杀 | 没有排队roll，不新增消费 |
| 预览意图、被拒绝的出牌 | 不消费，种子与事件保持不变 |

存活五次行动伤害仍为0/6/9/12/15，行动后力量仍为0/3/6/9/12。双Cultist保持各自首轮抑制，原整组轮末增长位置未变。

## 测试与夹具修订

新增 `tests/lua/cultist_rolls.lua` 14组真实Combat/Run测试。修改生产代码前，原基线5组通过、9组失败，失败包括缺主请求、真实种子未推进、洗牌顺序及死后队列。修复后14组通过。

其中一组新Blue同伴夹具初稿恰好形成连续两次Stab，合法的禁止三连规则使下一招固定Rake。夹具改为通过真实受控入口产生Rake→Stab历史，再验证死Cultist先消费0、Blue接收99并选择Stab。此修订后重新在旧生产基线运行，仍是5过9败，再恢复候选取得14过；没有改Blue规则或放宽断言。

新增8组schema测试覆盖生产范围100、缺失/零/负数/小数/过大/字符串及合法字段。连既有Cultist、Wizard、enemy AI与完整数据校验文件共119项通过。

广泛回归揭示六个既有夹具把真实Cultist当作不会抽样的同伴或隐藏前置条件：

- `acid_slime_s_ai`、`fixed_gremlin_rolls`、`queued_enemy_roll`、`queued_enemy_status`、`red_slaver` 的总请求数现明确包含活Cultist自己的1次post-action roll。没有关闭其AI、删掉死亡断言、改变伤害或修改被测敌人策略。共享queue回归额外断言Cultist请求发生在它自己的intent之后。
- `boss_reward_transactions` 的normal/elite金牌回归本来意在隔离奖励分派，却让开战抽样决定奖励输入。现明确注入原先的奖励入口seed20919/35128/17029，保留原奖励输出44130/58063/13080及卡牌顺序；三个入口数值来自旧seed1/42/65535的HP+9次洗牌共10次项目LCG推进。新Cultist用例单独验证真实Run仍执行新抽样，并非让正式游戏继续使用旧奖励种子。

## 本地验证层级

本切片正常JSON→Lua构建、UI测试前置构建、内容验证与相关JavaScript语法检查通过。最终全量原生Lua5.4的98个文件全部通过，119项相关JS检查重跑全部通过。首次UI前置构建由于重建快照缺少renderer文件失败，补取同SHA文件后重新构建成功；没有修改构建器。首次原生98文件跑89过9败，包含上述五个fixture及四个缺失helper文件；补齐同SHA helper后又暴露奖励fixture的种子耦合，按上文隔离输入修订后，完整重跑98/98通过。独立评审和最终当前SHA CI见PR记录。

没有安装依赖或运行被限制的完整npm check，不把原生Lua5.4代替Fengari、千星客户端或完整CI。没有平台编译、候选导出、官方导入或千星实机证据，TASK-15全池与平台AC仍保留。

## 仍未认证的差异

本项目生命、AI、洗牌及部分奖励仍共用16位LCG；原作使用独立流。本次补齐调用次数会改变本项目后续洗牌、同伴选招和奖励，但不证明RandomXS128、独立流初始化或原版种子重放一致。单Cultist单卡seed42在项目中的手算序列为HP22539→开场42944→Ritual后26841→首次Strike后6182；四卡开场按4/3/2继续洗牌后为50871，抽牌UID2/3/4/1。这些仅是本项目回归向量。

其它敌人缺失抽样、全池AI、逃跑/半死/特殊死亡、玩家死亡后的完整动作队列、原作PC版本真实性及所有平台关口不在本切片完成范围内。
