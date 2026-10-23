# TASK-15：祈火徒 Ritual 状态机候选

后续生产接线已由独立切片承接，见[TASK-15运行时账本](TASK-15-cultist-runtime.md)。下文保留本候选提交时的隔离范围和验证记录，不能据此推断当前生产仍未接入。

资料读取日期：2026-10-23。项目基线：`be5093f541724405154c4ee1c656fccc08e329e1`。

**仅离线候选，尚未接入 Combat、敌人数据或 UI。** TASK-15 仍为排队 To Do，全部 AC 保留。本轮没有原作实测、平台编译、存档导入或游戏试玩，不宣称原版一致性通过。

## 固定来源与行为事实

只读第三方反编译镜像 `purewhitelove/ButterflyGame`，固定提交 `fc379c875c11e008e9c10548ac8e394c301c532f`。[版本字段](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404)自称 V2.3.4 / 2022-12-18；**不是官方开源，未与正版 PC 二进制核验真实性**。已读取相关完整方法；只提取行为事实，未复制、执行或分发原实现与资产。

- [Cultist：构造函数32–56、takeTurn63–96、getMove131–145](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/Cultist.java)：A0 HP48–54、攻击6、Ritual3；首动施加 Ritual，此后只攻击，不重复首动。blob `991f46014688e8d7bfb673eb0c774fc7a257de52`。
- [RitualPower：构造及回调20–62](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/RitualPower.java)：敌方 Ritual 跳过施加当轮，之后每轮结束增加对应力量；玩家版本回调不同，不在候选范围。blob `6a0edd2d38fe616af6f8b1dc32f55414f750fe10`。
- [GameActionManager.update419–449](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java#L419-L449)：所有敌人行动完成后，才处理整组回合结束能力。blob `931cded5ae1aed78771e0a5389e8358946b78f8f`。
- [MonsterGroup.applyEndOfTurnPowers405–438](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/MonsterGroup.java#L405-L438)：先处理敌方回合结束触发，再依次处理玩家和存活、未逃跑敌人的轮末回调。blob `8a61dcf17de6560b9aa986bc99f54835acff5a52`。

由此推导无修正的单敌行动伤害轨迹为 **0、6、9、12、15**，不是原作录像结果。HP 分布及随机流、调用顺序未建模或认证。

## 候选与调用边界

`tools/candidates/cultist_ai.lua` 是独立编写、返回新状态的纯 reducer：

- 调用者传入 HP，原样保留；不以固定中点或自定抽样冒充原版随机。
- `act` 返回 Ritual 或基础伤害动作；实际伤害、虚弱/易伤、格挡、反伤、死亡与队友行动由调用者处理。
- `endRound` 必须在全部敌人及前置回合结束触发之后调用；首次跳过力量增长。
- API 按最新状态拒绝紧邻的重复动作/轮末调用，不防止旧快照重放；状态限定为平坦标量，不深拷贝任意嵌套扩展。它**没有团队调度器，不能识别调用者谎报“队友已完成”**。整组时序是明确输入契约，不是已验证的引擎保证。
- 不包含通用 Ritual 能力、逃跑、跳过敌方回合或持久化格式。

## 已执行验证

`tests/lua/cultist_ai_candidate.lua` 七组 Lua5.4 回归通过：首动与输入不变、五轮轨迹、队友行动间隙不增长、多实例隔离、行动/轮末前死亡、重复调用拒绝、输入 HP 保留。

- 缺模块红灯 exit1；实现后七组绿灯 exit0。
- 五个独立变异均被测试检出（exit1）：首动立即加力量、取消首轮跳过、单敌行动时提前增长、允许重复轮末增长、死亡后仍增长。
- JavaScript 语法检查 exit0；所有已有文件与固定基线 blob 相同。
- 使用已安装 `liblua5.4.so.0` 及现有 ctypes harness；未安装依赖。现有 Fengari 目录为空，**未运行 Fengari 或完整 `npm run check`**。局部通过不等于 CI 或运行时通过。

依赖可用时，仓库测试入口会自动发现此用例，也可单独执行：

```sh
node scripts/test-lua.mjs tests/lua/cultist_ai_candidate.lua
```

## 生产接线待办

当前祈火徒仍是攻击6与力量3交替；AI 仅支持睡眠循环和默认循环。已有 `hpRange` 接口使用项目 RNG，不代表原版随机已对齐。

1. 重新核对文件认领。此次 PR62 未改 combat/AI/schema；不得覆盖 Lagavulin 或其他并行工作。
2. 在整组敌人行动及回合结束效果之后增加轮末入口；**不能在逐敌 `EnemyAI.advance` 里加 Ritual 力量**。
3. 明确 Ritual 状态、首动意图/效果及 UI 展示契约。现有状态表无 Ritual，活动意图禁止空效果；不能伪装成立即加力量、放宽全局校验或隐藏核心信息。
4. HP48–54 可复用已有抽样入口，但须继续披露 RNG 算法/流/顺序限制，不新增种子、改抽取顺序或调平衡。
5. 补运行时首动显示、延迟增长、死亡/反伤、多敌时序、空效果拒绝、回滚/恢复、Lagavulin、事件快照与 UI 回归；完整测试及独立审查后才集成。正版 PC 与平台证据另验。

本轮未改共享 Backlog 元数据，不关闭 TASK-15，也未修复生产中的祈火徒差异。
