# 腐化之心：初代 PC A0 来源组件

本切片实现 Heart 定义、注册、AI、动作队列构造，以及供共享战斗调用的无敌与死亡律动回调。组件测试通过不表示第四幕可达、整场战斗通过或原生平台验收通过。固定来源为 `sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；12 个来源 member 与 SHA-256 见 `tests/fixtures/heart-source.json`，Java 来源没有复制到产品代码。

## 来源顺序与数值

生命 750，沿普通固定生命构造路径消费一次 monsterHpRng；不得设置 `noHpRoll` 或额外预抽。开战依次排无敌 300、死亡律动 1。

首招固定虚弱打击：易伤 2、虚弱 2、脆弱 2，然后按晕眩、黏液、伤口、灼伤、虚空各一张的顺序插入抽牌堆。其后每三招为两种攻击各一次（第一种由 Boolean 决定），然后强化。血弹为 2×12，回响为 40。每次选招都消费 primary 0..99，即使结果未使用；每个攻击对仅第一招额外消费一次 Boolean。

强化在 takeTurn 构造时读取当前力量：先排 `max(0,-strength)+2` 力量。附加奖励按强化次数依次为人工制品 2、死亡律动 1、源值 -1 的痛苦之刺、力量 10，随后每次力量 50。次数在构造时递增，不能推迟到队列执行时。

## 共享接入协议（本切片未接）

- `register(catalog,copy)` 注册独立定义；冲突报错，不覆盖既有 Heart/power。虚空已有定义时复用。痛苦之刺依赖既有 Act2 定义。
- `initialize/advance(state,enemy,random)` 只选招与消费 aiRng；`random(state,n)` 为项目现有 1..n 适配。`preBattle` 返回有序增益计划，不直接应用。
- `actions(state,enemy,intent)` 返回独立动作计划。共享行动器须使用它，不能直接执行 buff 意图中的 `heartBuff` 占位操作。
- `heartStatusDraw` 使用 cardRandomRng 逐张插入抽牌堆，空堆第一张不抽随机；初始空堆共四抽，非空共五抽。状态牌不因 Master Reality 升级。虚空抽到扣能量由已有抽牌路径负责。
- `capDamage(enemy,amount)` 接入扣格挡／Boot 之后、后续目标受伤钩子之前，覆盖普通、THORNS、毒与 HP_LOSS。它消费获准伤害额度，不按最终失血量扣额度；不能放进攻击预览计算。无敌优先级 99，额度归零仍保留状态身份和显示。
- `startTurn(enemy)` 在 Heart 自身回合开始、已排毒伤害执行之前重置额度。不可在玩家回合开始重置。
- `afterUse(state,enemy,physicalCard,enqueue)` 在每次实际用牌的效果之后、处置／消耗之前调用。`dontTriggerOnUseCard` 抑制；复制、自动打出按真实 UseCard 次数处理。返回的 `heartBeat` 已冻结来源与数值，必须在原队列位置执行 THORNS：不吃力量、虚弱、易伤，仍走格挡、无实体、缓冲、钨合金棍等受伤通道。
- `retained(effect)` 标明 `heartBeat` 在致命牌清场时仍保留；来源死亡不取消 THORNS。必须与共享 UseCard／DAMAGE 留存顺序一起验证。
- 共享 ApplyPower、痛苦之刺触发／UI必须支持源值 -1 的永久身份；当前叶模块不擅自改成正值。

共享 Actor、队列执行器、状态显示、目录装配和 Run 第四幕入口均未在本切片修改。上述钩子接好之后还需要真实 Combat/Run 的边界测试，不能用动作计划投影代替伤害结算证据。

## 独立验证

`tests/fixtures/heart-oracle.py` 使用独立 Python STS 随机实现按来源解释动作，不导入产品 Lua。六个种子覆盖零、正负、64 位边界，每种子连续 24 招，共 144 招；每份最后计数为 25 primary + 8 Boolean = 33。来源锁包含 oracle 与向量文件哈希。

`node --test tests/heart-component.test.mjs` 运行八组纯组件合同及来源锁检查，沿用 30 秒默认预算。覆盖注册隔离、开战顺序、完整 AI 随机轨迹、反向攻击、五状态顺序、负力量修复、八次强化、无敌零身份／重置和死亡律动冻结／致命牌留存协议。测试中的状态应用仅是计划投影，没有伪造共享战斗执行。
