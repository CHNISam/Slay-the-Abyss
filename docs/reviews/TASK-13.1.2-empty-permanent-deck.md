# 末张卡牌移除与空牌组

2026-10-24，TASK-13.1.2，连同 TASK-13.1 的商店删除和 TASK-16.1 的战斗入口前置。开发基线 `ee9c40d`，首发七事件范围不变，不引入新卡牌或事件。

## 问题和结果

核心曾把非空永久牌组当成开战前置，因此圣职者、净化神龛、金翼和商店都禁止移除最后一张卡牌，界面也显示“必须保留至少一张”。这一限制来自本项目，不能当作原版规则。

现在一张牌可以经原有 UID 选牌确认后移除；支付价格、商店每店一次和跨店涨价不变。空牌组正常开战，不补发初始牌，不消费不存在的抽牌/洗牌随机数；玩家仍可结束回合、使用原有药水和遗物，正常失败。未知卡牌、非表牌组和非法初始生命仍拒绝。

空牌组没有可选 UID，移除按钮显示“牌组为空”；失败不收费、不占服务。金翼的献祭选项仍可支付 7 点生命，空组直接完成，避免进入无法选择卡牌的死路。正常单牌献祭仍先扣血，取消不能退款、改选或重复扣血；若献祭致死，保留败局。

本片不引入瓶装牌、三种不可移除诅咒或其遗物；当前合法永久牌组没有这些定义。未来纳入时须按来源扩展移除资格，不能将“全部当前牌可移除”外推为全原版。

## 来源

固定社区反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，本轮经 GitHub connector 读取。没有复制镜像的实现代码、文案或素材。

| 文件 | Git blob | 核对方法和结论 |
| --- | --- | --- |
| [CardGroup.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/CardGroup.java) | `c68b25ad094b8cc04a0e380db8e67a1fb1f3bfe4` | getPurgeableCards 只排除特定不可移除诅咒，不因仅一张而排除；removeCard 不保留末张；initializeDeck 允许遍历空组 |
| [PurificationShrine.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/shrines/PurificationShrine.java) | `0f87121348226afda3814ba118db921c444447c8` | 选择净化组并移除所选卡，没有至少两张的前置 |
| [Cleric.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/exordium/Cleric.java) | `4783d9de97f23cb7ab13457d898b0fed58b7050f` | 资格是可净化组 size>0；A0 50金；不是 size>1 |
| [GoldenWing.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/exordium/GoldenWing.java) | `4bebe490cacf288ad25bd4042f48575cfb3b9bd2` | 献祭先受7伤，再进入净化；无末张或空组献祭禁用条件；原字节已保留于既有事件来源目录 |

该镜像不是正版 PC 二进制认证。原版零可选卡的原生列表交互没有在本轮原作客户端观察，项目采用明确禁用空移除和金翼空组直接完成；代价与最终状态不伪造，平台表现仍待验。

## 本轮验证

- `empty_permanent_deck.lua`：初版7组真实2过5败，修复后7过；补金翼空组献祭后真实7过1败，再修正后8/8。包括完整空组战斗失败、三种末张事件、商店支付/重入/再购和失败资产不变。
- `node_ui.lua`：修复前35组过后在新增末张按钮例失败；修复后37/37。通过现有生成控件的选牌和确认回调完成 1→0，空组拒绝且核心状态不变。
- `combat.lua`23、`nodes.lua`21、`cleric.lua`8、`unknown_events.lua`14、`inventory_restore.lua`5（8个恢复拒绝输入）均通过。既有对错误“末张保护”的预期改成无效UID/空组拒绝，保留资源、服务、价格和后续操作断言。

这些是显式单牌/空牌组事务夹具，不是自然构筑通关、同候选实机或 UI 总门禁。原始红绿日志保留 `.worktrees/m3-event-removal/*-red.log`、`*-green.log`。完整组合和当前 SHA CI 由本次 M3 整合另行记录。

没有编译或写入新 `.gil`、官方导入、开游戏或取本轮实机日志。TASK-13.1/13.1.2/16.1 的整体严格及平台验收仍保留，不因本片完成而 Done。
