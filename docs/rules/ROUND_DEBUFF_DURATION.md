# 虚弱、易伤、脆弱的共享轮末持续时间

核对日期 2026-10-23，基线 `52f35dd`，TASK-16.1 离线切片。采用 systematic-debugging、test-driven-development 与 verification-before-completion 工作流。

## 固定来源与证据等级

以下链接均固定社区反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`。镜像自称 PC V2.3.4 / 2022-12-18；没有与正版 PC 二进制哈希认证，不是官方公开源码，没有原作观察或本轮游戏实测。只读核对方法体，未运行、搬运或提交上游程序。

| 方法体 | 核实规则 | Git blob |
|---|---|---|
| [WeakPower constructor / atEndOfRound, 25–52](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/WeakPower.java#L25-L52) | 新 monster-source Weak 首次轮末只清 justApplied；之后每轮减 1 | `666e1245a4052f4f05f70f5e9c6e99bc840ac4d1` |
| [FrailPower, 21–48](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/FrailPower.java#L21-L48) | Frail 同上 | `d916009c6387f00834477c8f54b400fae753089f` |
| [VulnerablePower, 27–53](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/VulnerablePower.java#L27-L53) | Vulnerable 的首次跳过额外要求 turnHasEnded | `771737682ec41a9a40dd8cba333d6e0d3ea810ba` |
| [ApplyPowerAction, 174–202](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/common/ApplyPowerAction.java#L174-L202) / [AbstractPower.stackPower](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/AbstractPower.java#L180-L191) | 已有同 ID 时只增加层数，不替换实例，不重置原 justApplied | `2b9c1d950af65d3353cf59e20ec40745c08b2a45` / `3b42a1378440f8502d586744cacc94025d756996` |
| [GameActionManager, 425–480](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java#L425-L480) / [MonsterGroup, 405–438](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/MonsterGroup.java#L405-L438) | 所有敌人行动及敌方结束触发后，玩家再存活敌人轮末回调；战斗已结束不会再跑该边界 | `931cded5ae1aed78771e0a5389e8358946b78f8f` / `8a61dcf17de6560b9aa986bc99f54835acff5a52` |

本项目适用范围为当前玩家卡牌与敌人意图；`state.phase == enemy` 对应这个可达路径中的 turnHasEnded。怪物来源通过实际 source 引用识别，不以目标是不是敌人判断。公共 `Combat.addStatus` 是无来源的直接状态设置，不推测怪物施加。

## 差异、实现与独立预期

旧版在每个 owner 的 `Actor.endTurn` 减持续时间，玩家易伤 1 在敌人攻击前已清除。本切片将三个状态的数据 decay 和 rules.statusDurationTick 改为 round_end，由 `Combat.endTurn` 在整组敌人处理后调用 `Actor.endRound`，先玩家后存活敌人。扁平 `weakJustApplied` 等字段只在新建正层状态时初始化；已有层数叠加不会重置。字段随 Actor 的现有出牌事务回滚；清零后重新施加视为新实例。

| 验收输入 | 固定预期 |
|---|---|
| 玩家易伤 1，两名敌人各攻击基础 10，无其他修正 | 扣 15 + 15，80→50，轮末易伤 0；旧版为 60 HP |
| 玩家卡牌施加敌人虚弱 1，敌人基础攻击 10 | 本轮攻击 floor(10×0.75)=7，然后虚弱 0 |
| 敌人在其行动中首次施加某持续状态 2，下轮再施加 2，第三轮不施加 | 三轮结束后的层数 2 / 3 / 2；第二轮叠加不会重新跳过 |
| 玩家阶段从怪物 source 首次施加 1 | Weak/Frail 第一轮保留 1，下一轮归 0；Vulnerable 本轮参与受伤后归 0 |
| 玩家持续状态 1，最后敌人在开始行动前中毒死亡 | 胜利提前终止，未到轮末，状态保留 1；不制造额外衰减事件 |

专项 `tests/lua/round_debuffs.lua` 初始 15 组在旧实现真实运行：5 通过、10 失败，包含 80→60 与预期 80→50 的差异。修复后 17 组通过（增加出牌失败回滚、死敌持续时间与首次跳过标记不变）；既有 statuses 35、Fat Gremlin 11、Blue Slaver 9、Guardian 24、Cultist runtime 9 和 Cultist boundary 6 组，以及 schema 54 项通过。另核对 Combat 23、CardPool 93、Feedback 10、HP-loss 27、Inventory 11、Caps 12 组，全部通过。Fat Gremlin 的旧“毒死最后目标后仍轮末衰减”夹具改为只停止再次施加、保持战斗进行，死亡提前终止由专项显式覆盖。未删除旧测试组或缩短回归预算。整合后完整检查由主代理执行。

## 保留的缺口

未认证全部 power priority、同优先级插入顺序、排队执行与删除瞬间、Ritual 和其他状态之间的全局交错；本实现仍按现有确定性状态 ID 次序处理三个衰减事件。未核对特殊遗物改变 Weak/Vulnerable 倍率或免疫、跳过整组敌方回合等未纳入路径。原版 RandomXS128、独立随机流、seed 映射与调用顺序不在本片；项目 LCG 可复现不代表原版一致。

数据及宿主自动测试是本片证据，没有执行平台编译、存档副本导出、官方导入、原神或千星实机。TASK-16.1 全项 AC 保持未勾。
