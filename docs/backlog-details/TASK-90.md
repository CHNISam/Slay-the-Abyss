# TASK-90 遗物绑定说明

本轮基线 `cd2e4a4a`。`abyss_uncommon_relics.equipBottle` 将三种瓶装遗物绑定到具体卡牌实例的 `inBottleFlame/Lightning/Tornado` 标记；`abyss_opening_hand.stage` 将绑定牌放入战斗起手序列。`abyss_living_wall.purgeCards` 排除这些牌以及三类不可移除诅咒，事件继续沿用同一筛选与 UID 复验。

七个两幕事件/营地/选择说明模块将未解释的“非瓶装”改为“遗物绑定牌除外”，在移除正文解释“被遗物指定为战斗起手的牌不能移除”；复制品不继承遗物绑定。规则、奖励、随机流、筛选与命令没有变化，第三幕 full-source 保留。

生成本树数据/UI 后，原有 BackToBasics、Act2 event content/UI 共10项 Node 回归通过，覆盖绑定牌、不可移除诅咒、UID重排、过期选择、取消与已付款流程。独立审查 `/root/release_audit` PASS，无未解决项。源码检查不代表官方导入或当前设备显示，设备验收尚未完成。
