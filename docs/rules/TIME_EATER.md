# 第三幕 Time Eater：A0来源合同

目标仍是初代PC A0。固定资料为社区反编译镜像 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，不是官方开源或认证PC二进制。仅定向读取Java方法，独立编写Lua/Python；不把Java原文加入产品。16份文件的逐字节SHA256与Git blob身份在[来源锁](../../tests/fixtures/time-eater-source-contract.json)。

## 责任边界

`abyss_time_eater`独立拥有敌人定义、决策、Time Warp与Haste动作。Act3 Boss登记/来源解析和EnemyAI仅委派；Combat保留出牌事务、既有原生/高级队列及结束回合责任，CardActions保留抽弃/消耗/复制责任。没有新增动作管理器，不改变卡牌、遗物或其他Boss规则。取消消耗在高级队列复用既有`abyss_exhaust.move`，保留Sentinel的TOP能量先于已排力量、Dark Embrace/FNP的BOT回调晚于力量。

| 固定来源方法 | 本片精确行为 |
|---|---|
| [TimeEater构造、getMove、takeTurn](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/beyond/TimeEater.java) | HP456仍消耗一次固定范围生命抽样（setHp(456,456)）；每次roll主抽0–99。0–44回响7×3，45–79震颅26后抽牌减少1，80–99涟漪固定格挡20后易伤1、虚弱1。无A19脆弱、黏液或额外格挡。 |
| 同一getMove | 禁止连续三次回响；命中此限制额外抽50–99。震颅不能连用，命中限制额外抽Java `0.66f`概率浮点，成功回响否则涟漪。涟漪不能连用，命中限制额外抽0–74。递归不是重新抽主roll，保留每次消费。 |
| 同一getMove、takeTurn | HP严格低于228且未选择过Haste，在下次选招时选择一次；伤害不会立即打断意图。先移除减益，再显式移除Shackled，再执行行动时捕获的`228-currentHP`治疗量（包括负值），最后roll。正力量保留；负/零力量移除，Shackled不归还。 |
| [TimeWarpPower.onAfterUseCard](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/TimeWarpPower.java)、[UseCardAction.update](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | 本张效果之后、实体牌处置及消耗回调之前计数；12时重置0，停止后续自动出牌，取消牌的处置先排队，再排每个敌人力量2，当前动作队尾排空后交既有结束回合流程。计数跨回合；复制/自动使用的实际使用均计数，实体`dontTriggerOnUseCard`为真时不计。 |
| [GameActionManager.callEndTurnEarlySequence](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | 清空后续cardQueue；自动牌不执行效果、不增加计数，保留原先消耗/弃牌/洗回/Power或purge处置。取消消耗反应加入同一队列：Sentinel等卡牌TOP回调先于已排力量，Dark Embrace/FNP等Power的BOT回调保持在力量之后。 |
| [AbstractCard.makeStatEquivalentCopy / makeSameInstanceOf](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | 新构造不复制`dontTriggerOnUseCard`瞬时实体标志；只在复制助手中清除此字段，其他既有复制身份/费用责任不变。Giant Head切片拥有实体字段穿透与普通处置后的共同重置。 |
| [DrawReductionPower](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DrawReductionPower.java) | 首次施加每回合正常抽牌减1，Artifact可以阻挡；叠加只延长持续。施加当轮跳过衰减，随后轮末减1；普通卡牌抽牌不减。 |

RemoveDebuffsAction按来源Power顺序逐项addToTop，因此实际移除顺序反向；Haste保留这一顺序，再执行显式Shackled移除与治疗。不把“加速”误写成正力量归零，也不把行动时确定的HealAction误写成结算时强制设为半血。

## 离线验证与未验证

[受控Lua测试](../../tests/lua/time_eater.lua)覆盖概率边界、额外抽样边界、三种攻击/状态、Haste顺序、两条既有队列、12牌时点、复制/取消/实体旗标、死亡/队尾、异常原地回滚、真实Run第三幕Boss来源入口及单次结算、中文意图与0/12计数。独立[Python方法解释](../../tools/oracles/sts1_time_eater.py)生成3个种子×12回合向量，断言完整aiRng/monsterHpRng快照。长轨迹使用1000生命与受控HP跨阈值，仅为观察算术，不是自然冒险。

中文名、计数、抽牌减少、Haste清除/治疗均读核心；原生图标复用现有主题。继承既有消耗能力边界：高级消耗仍显式拒绝非空`onExhaustRelics`，未补Strange Spoon、Dead Branch、Charon's Ashes或自定义消耗回调；`returnToHand`目前没有产品卡牌表示，本片不声称支持它。取消处置只覆盖现有弃牌、消耗、洗回、purge与Power分支，不能由此推称原版所有处置/遗物交互齐备。

没有占用键鼠，没有官方导入/原神实机截图，没有原作PC执行，也没有完成四职业自然连续三/四幕通关。因此本片不是整幕、M3或实机验收通过声明。
