# 迟缓小魔：首幕 A0 普通攻击切片

2026-10-23，基线 develop `ed39f4653ddb555391c0dfe5a4507d1f58387171`。
归属 TASK-15 的独立离线候选，不接管已有任务负责人，不完成全池或平台验收。

## 固定来源与预期

只读核对两个固定反编译镜像的 `GremlinFat` 构造、`takeTurn` 和 `getMove`：

- [aeubanks/sts@319009d](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinFat.java)
- [purewhitelove/ButterflyGame@fc379c8](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/GremlinFat.java)

两者均给出：A0 生命闭区间 13–17；普通动作每次先排入基础伤害 4，再施加虚弱 1；每次决策重新选择同一个攻击减益动作。脆弱只在 A17+ 分支出现，首发 A0 不加入。原数据把伤害和虚弱拆为两个轮流动作，导致首轮没有虚弱、第二轮不攻击。

这些镜像非官方发行物，也未认证对应正版 PC 二进制；两份一致不能证明独立来源。本次未运行、分发或复制原程序，仅独立修改本项目数据。预期来自上述方法体，不是原作客户端观察。

## 最小实现

仅修改 `data/enemies.json` 中迟缓小魔：使用已有 hpRange 采样入口；合并为一个 attack 意图，effect 顺序为 damage4、applyStatus weak1。现有单意图循环即可重复，不引入 AI 框架或修改共享战斗内核。中文名称不改。保留 hp15 作为既有静态代表值，实际 maxHp 使用采样值。

现有全遭遇回归对非状态机敌人一律断言固定 HP，现仅在定义明确包含 hpRange 时验证区间和 maxHp，并继续断言处理意图前后的实际 HP 不变；所有其他固定 HP 敌人仍按原数值断言。

## 验证与边界

新增 Lua 测试采用固定数值预期而非读取配置生成预期：首轮及五轮轨迹、伤害先于虚弱的事件顺序、全格挡和零伤害仍施加虚弱、虚弱持续到玩家回合并在玩家轮末衰减、真实 Strike 受弱、状态修正、多实例叠加、毒致死不行动，以及原遭遇数据的 Run 入口。Run 测试显式设 floor5 为 host-entry 夹具，不声称实际走过地图。

其中持续时间测试仅覆盖既有核心的玩家轮末衰减约定，不认证原版 WeakPower 的 end-of-round／justApplied 调度或全局轮末顺序一致。

HP 检查覆盖 128 个项目种子，13–17 每个值均可达，maxHp 相等且重复种子稳定。使用的是既有 LCG 接口，新增 HP 抽样会推进现有随机流并影响后续洗牌；这不是原版 RandomXS128、独立随机流、原版种子映射或抽样顺序认证。

未实现第二幕 Gremlin Leader 情境下的逃跑/死亡通知；未改变首幕现有五敌编组，其合法性仍是已知未完成项。反伤致死后的排队效果、全局死亡/结算队列顺序仍归 TASK-16.1，本切片不为这些共享行为背书，也不声称整个敌人已经严格一致。

系统 Lua 5.4 离线验证不等于 Fengari、Windows CI、千星编译、导入或实机。完整检查和独立审查以最终提交当前 SHA 的实际记录为准；所有相关平台与全池 AC 保持未完成。

