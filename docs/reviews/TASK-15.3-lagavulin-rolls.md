# TASK-15.3 · 沉眠遗卫分阶段选招的随机消费

## 有限生产缺口

基线 `ac90e1ed873e4dba15188d74aad72f51c5a39f21` 已有 Lagavulin 的生命109–111、8睡眠格挡、自然三回合醒来、失血惊醒/眩晕，以及18/18/敏捷力量各-1的循环。但 `sleep_then_cycle` 不曾请求选招随机数，遗漏继承初始化及多个已排队 RollMove。

此切片只修改该策略的消费位置，并为它增加经过校验的 `rollRange: 100`：

- 初始化消费一次；仍选 Sleep。
- 第1、2次睡眠行动各消费一次；第3次自然醒使用 SetMove，不消费。
- 受伤或非致死毒伤惊醒后的眩晕行动消费一次；伤害发生本身不消费。
- 每次清醒攻击、减益行动后消费一次。
- 攻击中被荆棘反杀、仍有活队友时保留已排队roll；最后敌人死亡清队列，行动前毒死或被玩家杀死不产生roll。

生命、格挡、伤害、惊醒时点、动作循环和其它敌人策略不变。不把动画/对话的 MathUtils 随机请求当作 AI 抽样。没有重写共享 Combat 调度器。

## 固定来源与身份

2026-10-23 UTC 读取社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，全部文件以base64原始字节解码并复算Git blob匹配。版本字段自称 `[V2.3.4] (12-18-2022)` / `2022-12-18`；未与正版PC JAR/hash认证，不是官方开源、原作录像或本轮PC实测。只根据方法关系独立实现行为，没有移植或编译来源代码。

| 固定来源 | 方法事实 | Git blob |
| --- | --- | --- |
| [Lagavulin.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Lagavulin.java) | takeTurn的攻击、减益、眩晕及前两次睡眠排入RollMove；第三次睡眠只排OPEN/SetMove；getMove忽略num | `57e7a86b61d31b9fba03000ae31e9ae433e1122d` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | init调用rollMove；rollMove请求aiRng.random(99) | `4784e38e7afff5980736e2b5c718e62a0c838c47` |
| [Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | int包装为nextInt(range+1)，闭区间0–99 | `c4b71d5645688f6e764c46c593223eb91a5249bc` |
| [RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | update无owner死亡保护，直接rollMove | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` |
| [ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | 反伤排在队首，先于原队尾RollMove | `e898e2f525a6eb49664eadb847dacb681f2931fe` |
| [DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | 全部怪物基本死亡后清理战斗动作 | `ea89aeab60af8a7c297495de3cd8eb82d7130232` |
| [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | cleanup不保留RollMove；先排空动作再处理下个怪物 | `1662da8de2aeb42044b385f03d0c801750904b13` |
| [MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | 基本死亡按isDying/isEscaping判断 | `7096970a151840489a3fba89806e6391e0d82d76` |
| [CardCrawlGame.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java) | 版本声明，仅为镜像自述 | `6f15eb15977a40bcb6e95598513a3073310eacd3` |

Lagavulin原始UTF-8 SHA256：`818b6a5681e30ca6681b035a1dedca477b2f626c873d98f320a58e6d2ed09e87`。队列边界与既有[死后选招账本](../rules/QUEUED_ENEMY_ROLL_AFTER_DEATH.md)一致，不以固定动作推断“没有随机数”。原作事件版清醒开局（setAsleep=false）未进入本项目合法遭遇，不在本切片扩展。

## 独立输入与回归

新增 `tests/lua/lagavulin_rolls.lua` 17组，通过真实Combat/Run入口验证，不直接调用EnemyAI或替换其实现：

- 原作0/99端点映射到当前1..100包装，两者均消费但不改变Sleep。
- 自然睡眠逐回合累计请求为1、2、2；格挡8、8、0，前三回合玩家不失血。
- 清醒四行动仍为18、18、0、18伤害，每行动各一次主roll，减益仍为敏捷/力量各-1。
- 初始和第三个准备回合的伤害惊醒、非致死毒伤惊醒均为一次眩晕行动roll，而非伤害触发roll。
- 有同伴时反伤致死的Lagavulin先消费，随后实际Cultist行动再消费；下一回合不再消费死者roll。
- 末敌反伤死、行动前毒死、玩家牌杀、预览/拒绝出牌均不新增roll。
- 两只Lagavulin的受伤醒与自然醒独立；失败出牌恢复HP、Block、阶段、种子及表身份。
- 真正Run精英入口与火瓶惊醒保持同一消费时序。

手工核算的项目LCG向量（非原作RNG向量）：seed42 → HP请求22539 → 开场42944 → 睡眠1后26841 → 睡眠2后6182 → 自然醒仍6182 → 首次攻击后50871。四卡开场请求顺序为3/100/4/3/2，最终seed50871、抽牌UID2/3/4/1；仅用于验证本次真实消费对项目共享LCG/洗牌的影响。

17组在原生产代码上先5过12败，失败对应漏请求、种子、洗牌和死后队列；修复后17过。Run夹具初稿漏设精英合法floor，先修为floor6并在旧生产代码重新证红，未以wrong_floor作为机制失败证据。新增8项schema正反例检查缺失/零/负数/小数/超限/字符串和合法范围，连现有enemy AI与Cultist检查共34项通过。没有修改既有测试预期或其它敌人AI。

## 本地验证与剩余关口

- JSON→Lua正常构建、UI测试前置构建、数据校验和修改的JS语法检查通过。
- 完整99个原生Lua5.4文件通过，包含本次17组及既有Lagavulin、Ritual、队列、状态、卡牌、库存和UI用例。
- 181个未改动的已物化runtime/data/Lua/helper文件与基线Git blob逐byte吻合。初次自写运行器未携带仓库LUA_PATH、battle UI布局注入及candidate helper副本，84/99过；补齐既有运行条件后重新跑完整99/99，失败日志保留，没有改业务或放宽断言。

没有安装依赖或运行受限的完整npm check，不把原生Lua5.4等同于Fengari或最终CI。独立评审及当前SHA的Quality结果由对应PR记录；本切片不提供平台编译、候选导出、官方导入或千星实机证据。

本项目仍让生命、AI、洗牌及部分奖励共用16位LCG；原作独立随机流与RandomXS128尚未接入。补漏会改变项目后续牌序/队友选招/奖励，但不证明原作种子重放一致。其余敌人、全动作队列、版本真实性与TASK-15全池及平台AC仍保留，不据本切片勾选或宣称完整原版一致。
