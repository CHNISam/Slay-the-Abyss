# 绽放印记：玩家治疗封禁

本片基线 `0c07e3dc`，固定来源 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。`tests/fixtures/mark-of-bloom-source.json` 记录实际读取的ZIP及16个原始成员摘要。它是社区反编译镜像解释，不是认证PC二进制或平台证据。

## 来源与范围

MarkOfTheBloom是SPECIAL遗物，来源ID `Mark of the Bloom`，`onPlayerHeal` 返回0。AbstractCreature.increaseMaxHp先增加最大生命，再请求同额治疗；印记只让治疗为0，不撤销最大生命。AbstractPlayer致死分支还显式阻止Fairy及Lizard Tail；现有Fairy实现已经识别两种印记ID，本片通过真实Run回归确认药瓶保留，未新增或宣称完整Lizard Tail实现。

生产ID为 `mark_of_bloom`，中文名“绽放印记”。`Run.obtainRelic` 可合法命名获得，source/local ID归一且重复获得拒绝。它不进入普通遗物队列。149项注册顺序、130项队列、缺失89项队列效果与95项第一幕效果均不变；仅新增后幕SPECIAL映射，已映射注册项47→48，本地定义51→52（含3职业专属和1后备）。图标明确使用主题占位，未宣称专属美术通过。

## 全通道审计与接线责任

| 通道 | 本片处理或既有行为 |
|---|---|
| 血药、果汁 | 现有PotionHealth共享治疗函数补来源ID识别；果汁仍增加最大生命、消耗瓶子，实际治疗0。 |
| Meal Ticket、战外Toy、Strawberry | relic_hooks的直接治疗检查印记；Strawberry最大生命+7保留。 |
| Blood Vial | 真实开战hook实际治疗0，原事件/受伤阈值接口保留。 |
| 再生 | Actor轮末仍衰减层数、保持事件结算，玩家治疗0；敌方再生不变。 |
| 卡牌、遗物、Self Repair排队治疗 | 既有CardActions路径已用PotionHealth，来源ID识别与印记生效；原无印记数值保持。 |
| Reaper续接、Feed | 原直接加HP绕过补印记检查；Feed最大生命+3等仍生效，敌人受伤/死亡路径不改。 |
| 原创四角色共用health owner | 内部治疗入口在实际治疗额度和芙宁娜fan记账之前拒绝治疗；Mark不消耗治疗额度、不产生fan。无印记的角色治疗设计与数值不改。 |
| Run.heal、increaseMaxHp、Moai/Library/Winding等 | 原先已检查两种印记ID；本片实际命名获得后复验Run入口。 |
| 营地、Cleric、战后Burning/Black Blood | 父线程独占Run/Nodes：营地实际已走Run.heal；营地/Cleric预览需为0，Cleric和战后直接加HP需转Run.heal。此树不修改这些文件，等待父整合验证。 |
| 敌人治疗 | Awakened再生、Time Eater、敌人吸血、同伴治疗保持，不能因玩家印记被封禁。 |

复用既有 `abyss_potion_health.blocked(relics)` 提供纯Mark判断，接受两个精确ID。没有新增模块、全局治疗框架或兼容层；Mark-only旁路不会改变无Mark路径的Magic Flower等既有数值。异常仍走原调用者事务传播，不吞错。

## 实际验证

先写36组共享入口/无Mark控制。第一轮夹具误用了Actor内部tick，修正为公开endTurn后再运行：12组无Mark控制全过，现存MealTicket/Strawberry/BloodVial/Reaper/Feed/Regen/原创治疗绕过真实RED，893毫秒；修复后36组GREEN，870毫秒，最终同组重验1168毫秒。两个精确ID及四原创角色均覆盖。敌人再生仍+3、层数仍减1。

数据和真实命名获得另先RED：缺SPECIAL定义、Run返回relic_content_unavailable。补齐后4组真实Run GREEN，2168毫秒：两ID获得与重复拒绝、最大生命/Strawberry、战外血药/果汁/Toy、开战BloodVial与致死Fairy。它们是受控组件边界，不是自然通关。

新源/schema测试及既有9项完整遗物账本合同通过，包含未知hook拒绝、原队列方向、稀有度分区、首尾消费与缺项不可伪装。架构193模块/1125边通过；固定Luacheck1.2.0为84条历史诊断、0新增，358项职责测量保持原门槛，未更新基线或增加豁免。原Lua每份30秒不改。

最终必要邻接：原 `potion_health` 22组通过（8.607秒），原 `common_relic_hooks` 9组通过（2.960秒）；完整launch-content机器合同20项通过（20.091秒），包含真实Lua运行时集合、事件/遗物清单与负例。不是完整玩法或父Run/Nodes修复后的验证。

命令：`node --test --test-concurrency=1 tests/mark-of-bloom.test.mjs tests/mark-of-bloom-source.test.mjs tests/sts1-relic-pool-catalog.test.mjs`。其余必要组合与最终CI由父线程完成。

## 未验范围

MindBloom升级事件自然接线、父Run/Nodes治疗修复汇合、完整场景/战后复验及整局、同一GIL、官方导入、实机与UI验收仍待完成。清单记录的是已实现组件和明确的预定SPECIAL渠道，不等于该自然渠道已经验收。不关闭TASK-62、TASK-14.1或M3，无GUI或键鼠操作。
