# 数值与内容数据（表驱动）

所有玩法数值放在这里，改数值不改代码。首版为**草稿**，数值来源：初代《杀戮尖塔》公开 wiki 的常见数值，
作为平衡起点，**上线前需在真机试玩中逐条核对**（见 TASK-7 备注）。

## 文件

| 文件 | 内容 |
|---|---|
| `statuses.json` | 状态效果定义（叠加规则、结算时机） |
| `cards.json` | 战士卡池 75 张（3 基础 + 20 普通 + 36 罕见 + 16 稀有）+ 3 状态牌，数值照搬官方，只改名不改数 |
| `enemies.json` | 敌人 19 变体 / 14 普通遭遇组 / 3 精英 / 1 Boss |
| `relics.json` | 遗物 |
| `potions.json` | 药水 |

## 约定

- 数值单位：伤害/格挡为整数点；`cost` 为能量。
- `upgrade` 只写与基础版不同的字段，未写的继承基础版。
- 效果用 `op` 标签描述，由实现层解释：
  `damage` / `damageAll` / `block` / `draw` / `energy` / `applyStatus`（对敌）/ `gainStatus`（对己）/ `discardRandom` / `damageEqualToBlock` / `heal` / `addCardToDiscard`
- 卡牌文案（`text` / `upgradeText`）为本项目自有实现，不搬运他人资产。
