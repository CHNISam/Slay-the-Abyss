# TASK-16.1.1 · 已打出能力牌的去向

## 已复现问题与有限修复

基线 `f175acac88416b0ac59946be83bb0c3e9c843fe8` 的 `Combat.resolvePlay` 把 `card.type == "power"` 与 `card.exhaust` 合并处理。已在合法卡池中的 Inflame / Barricade（含升级）打出后会进入消耗堆；原生战斗界面的消耗计数也因此错误增加。

本切片只修正**成功打出后的目的地**：能力牌不加入抽牌、手牌、弃牌或消耗堆；其已结算的状态继续生效。非能力牌仍按原 `exhaust` 标记进入消耗堆或弃牌堆。能力牌分支先于 `exhaust` 标记处理。

未打出的能力牌不因此消失：它们仍走原 `endTurn` 手牌处理路径，普通能力牌弃入弃牌堆后可以重新抽到。永久 Run 牌组不变，下一场战斗仍生成新的能力牌实例。不新增“已用能力牌堆”，不改卡牌数值、费用、状态效果、随机数、界面布局或合法池范围。

## 固定来源及认证边界

只读核对社区反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f` 的实际方法体，并重新计算下载内容的 Git blob SHA。这里没有正版 PC JAR hash，不是官方开源、原作实测或完整能力牌系统验收；没有把第三方代码复制到运行时代码。

- [UseCardAction.update](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/utility/UseCardAction.java)：POWER 分支调用 `hand.empower` 后提前返回，在普通弃牌/消耗分支之前，不进入 `moveToExhaustPile`。
- [CardGroup.empower / moveToExhaustPile](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/CardGroup.java)：empower 与消耗路径独立；消耗路径另有 exhaust pile 写入与消耗钩子。
- [SoulGroup.empower](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/SoulGroup.java) → [Soul.empower](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/Soul.java)：演出分派后的目标 group 为 null，不将能力牌加入另一张卡组。

| 文件 | Git blob SHA | SHA256 |
| --- | --- | --- |
| UseCardAction.java | `3069a750b5c07b1a1c8aebfcf021984cad9a8a5a` | `f4dd74db285f6952c727a45a1b445f96053ac5ca86082f237fb2d62689979e4f` |
| CardGroup.java | `c68b25ad094b8cc04a0e380db8e67a1fb1f3bfe4` | `e0be13845c3ef51d89749b5826c81bab3b48d9c12307d5f4329294475ba86561` |
| SoulGroup.java | `e6a9319aa70986320706511b8bb520e29843f5eb` | `05a6d28a2607c4f3dd073a626b3d3b71f6bcb6d0b6e8ffbca13bef24796b7452` |
| Soul.java | `a116e6bdc527712487087065fa8ac429935ab95a` | `a0e4466faf2000370cc9902eb98f5c90e18365e52dac9c79f02470f93931d6f6` |

## 独立预期与测试

`tests/lua/power_card_lifecycle.lua` 提供 19 组行为检查：

- Inflame / Barricade 基本与升级的使用去向、原费用/状态结果、原随机状态、重复 UID 拒绝和后续回合不再抽到已用实例。
- 未打出、能量不足、已用能力牌的永久牌组与下一场新实例边界。
- 受控 `power + exhaust` 标记优先级，及真实 Impervious 的消耗对照。
- 通过现有生成原生树与真实 GameUI/BattleUI 控制器点牌，验证 Inflame 后消耗计数为 0，随后 Impervious 后为 1；这仍是离线控制器测试，不是千星实机截图。

测试先于生产修改。新套件对未修基线失败 14/19，最小生产修复后 19/19 通过。`card_pool.lua` 与 `atomic_play.lua` 中原有“能力牌进消耗堆”的错误断言分别先红再绿，保留所有效果、原子性和牌组检查。

本地原生 Lua 5.4 回归共 95 个文件通过，包括 19 组新增、93 组全池行为、14 组原子性及 25 组虚无/消耗生命周期。使用既有生成夹具，未重建生成文件；未安装依赖，未运行完整 `npm run check` 或 Fengari CI。远端当前 SHA Quality、独立评审与合并结果应以最终 PR 为准。

保留范围：完整 onUse/onAfterUse/onExhaust 钩子、未支持能力牌、原版动画时间、原版随机流、正式副本构建、官方导入与平台试玩均不在本切片，不因此关闭 TASK-16.1、M1 或 UI 总门禁。
