# TASK-14.1 首发遗物 / 药水离线核对

核对日期：2026-10-23。目标为**初代 Slay the Spire PC 正式版、Ascension 0**，不使用二代数据。此次未运行原作，未取得原作可执行构建号或录像；下表的日期是查阅资料的日期，**不是原作实测日期**。资料为社区维护的初代 Wiki 与玩家直接观察，不等价于锁定 PC 构建的实测。严格一致性及平台 AC 保持未勾选。

## 逐件账本

表中的输入都从 `Run.startCombat` / `Run.usePotion` / `Run.endTurn` 等真实库存入口执行。固定预期写在 `tests/lua/inventory_parity.lua`，不从当前 JSON 动态计算。开局基数为 5 手牌、3 能量、80 最大生命；其他未说明的遗物与修正不在输入中。

| 项目 / 资料章节 | 资料支持的值与时机 | 当前位置与差异 | 验收输入 → 固定预期 |
| --- | --- | --- | --- |
| [Burning Blood · Description / Update History](https://slay-the-spire.fandom.com/wiki/Burning_Blood) | 战后回复 6；死亡不回复 | `relics.json:burning_blood`、`Run.finishCombat`；仅胜利一次，先提交生命再给奖励 | 40 HP + 火药击杀末敌 → 奖励界面 46；重复 finish → 仍 46；失败不回复见 `run.lua` |
| [Anchor · Description / Rarity](https://slay-the-spire.fandom.com/wiki/Anchor) | Common；开战 10 Block | `relics.json:anchor`、`Run.startCombat`；基础抽牌后执行，精确开战队列顺序待核实 | 六件开局遗物 → Block 10；次回合 0；下次战斗再得 10 |
| [Vajra · Description / Rarity](https://slay-the-spire.fandom.com/wiki/Vajra) | Common；开战 1 Strength | `relics.json:vajra`、`Inventory.apply`；场内保留，战后清理 | 开战与次回合 Strength 均 1；下场仍 1，不累积到 2 |
| [Bag of Preparation · Description / Interactions](https://slay-the-spire.fandom.com/wiki/Bag_of_Preparation) | Common；开局额外抽 2 | `relics.json:bag_of_preparation`、`Run.startCombat`；当前在普通 5 抽之后；与 Innate / 生成牌的相对顺序未验收 | 开局 7 张；次回合普通 5 张；下场重得 7 张 |
| [Lantern · Description / Rarity](https://slay-the-spire.fandom.com/wiki/Lantern) | Common；第一回合额外 1 Energy | `relics.json:lantern`、`Run.startCombat`；不被首回合能量刷新覆盖 | 首回合 4 能量，次回合 3，下场首回合 4 |
| [Oddly Smooth Stone · Description / Rarity](https://slay-the-spire.fandom.com/wiki/Oddly_Smooth_Stone) | Common；开战 1 Dexterity | `relics.json:oddly_smooth_stone`、`Inventory.apply` | 开战与次回合 Dexterity 均 1；下场仍 1 |
| [Bronze Scales · Description / Rarity](https://slay-the-spire.fandom.com/wiki/Bronze_Scales)、[Thorns · Description](https://slay-the-spire.fandom.com/wiki/Thorns) | **Common**；开战 3 Thorns；按攻击每段触发，非按扣血触发 | `relics.json:bronze_scales` 原误记 Uncommon，已改 Common；`Actors.damage` 原排除 0 伤害攻击，已修 | 敌方 1 基础攻击 / -1 Strength，单段扣敌 3，三段扣 9，玩家不掉血；敌剩 3 → 首段反杀、截断后段、Burning Blood 只回 6 |
| [Fire Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions) | Common；对所选敌人 20 非攻击伤害 | `potions.json:fire_potion`、`Inventory.apply`；固定伤害经过 Block、不受 Strength / Weak / Vulnerable，不触发 Thorns | 敌 7 Block + 玩家 Strength/Weak + 敌 Vulnerable/Thorns → 敌扣 13 HP，玩家无反伤；见 `inventory.lua` |
| [Block Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions)、[Dexterity · Description](https://slay-the-spire.fandom.com/wiki/Dexterity)、[Frail · Debuff](https://slay-the-spire.fandom.com/wiki/Debuff) | Common；12 Block；Dexterity / Frail 描述限定来自牌的格挡，故不套用于药水 | `potions.json:block_potion`、`Inventory.apply`；固定 12 的语义保留，**不将其盲改为卡牌格挡** | Dexterity 药水后 + Frail，Block 药水得 12；接着 Defend 再得 5，总 17；最终 Block 上限 999 另见 `inventory.lua` |
| [Strength Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions) | Common；2 Strength，持续本战 | `potions.json:strength_potion`、`Inventory.apply`；不是 Flex 的临时力量 | 使用一次 → Strength 2；能量仍 3；手牌/弃牌/消耗堆不变 |
| [Dexterity Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions) | Common；2 Dexterity，持续本战 | `potions.json:dexterity_potion`、`Inventory.apply`；不是 Speed Potion | 使用一次 → Dexterity 2；能量仍 3；Defend 遵循先加敏捷后 Frail |
| [Energy Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions) | Common；本回合增加 2 Energy | `potions.json:energy_potion`、`Inventory.apply` | 3 能量使用 → 5；不算出牌、不抽牌 |
| [Poison Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions)、[Poison · Debuff](https://slay-the-spire.fandom.com/wiki/Debuff) | Common，Silent 专属获取；对目标施加 6 Poison，目标回合开始扣血后减 1 | `potions.json:poison_potion`、`Inventory.apply` / actor tick；效果存在，当前荧/战士的**获取池未限制角色**，留给 TASK-13.1 | 使用后无即时伤害、Poison 6；目标回合开始扣 6 HP、Poison 5，穿透 Block |
| [Regen Potion · Potions/List of Potions](https://slay-the-spire.fandom.com/wiki/Potions)、[Regeneration · Description](https://slay-the-spire.fandom.com/wiki/Regeneration) | Uncommon；5 Regen；自己回合结束先按层数回血，再减 1；结束战斗不补一次 Regen | `potions.json:regen_potion`、actor tick / `Run.finishCombat` | 两瓶叠至 10；40 HP 结束回合先回 10 后受 6 攻击 → 44 HP，余 9；末敌被火药击杀 → 不触发 Regen，仅 Burning Blood 回 6 |

无随机数值/概率的效果在表中列固定数值；获取概率、商店价格、随机遗物池及掉落不由本任务修改。

## 零伤害反刺的证据与回归

Wiki 的 [Thorns](https://slay-the-spire.fandom.com/wiki/Thorns) 将触发定义为每次被攻击，区别于必须损失 HP 的触发。对边界的直接观察为 [2020-05-07 玩家讨论](https://www.reddit.com/r/slaythespire/comments/gf9v3d)：回复明确报告无格挡 0 伤害和有格挡 0 伤害仍会反刺。该来源为玩家观察，不含 PC 构建号，仍须原作复验。

修复前，在 `c2c2cd2` 生产代码上运行新增测试，观察到：

- Bronze Scales 稀有度：`uncommon ~= common`。
- 单段 0 伤害：敌仍 50 HP，预期 47。
- 敌剩 3 HP 的三段 0 伤害：敌仍 3 HP，预期 0，未进入战后回血。
- 固定非攻击伤害的负例已通过，证明不应把所有伤害都改为反刺触发。

修复只删除 `Actors.damage` 中普通攻击触发 Thorns 的 `amount > 0` 限制，保留 `not fixed`，并改正数据稀有度。旧 `statuses.lua` 把 0 攻击写成不反刺的断言同步改正；新增测试从真实库存获得铜鳞后走敌方回合，独立于该旧错误预期。同步到 `a6be1b6` 后，PR #37 新增的 `block_damage.lua` 也出现同一旧预期（0 Block 的 Body Slam 不反刺），该用例已按同一来源改为玩家损失 3 HP；未改变 Body Slam 算法。

## 精确时序与库存边界仍待完成

- 当前开战为 `Combat.new` 完成回合刷新与基础抽牌后，按取得顺序遍历全部 `combat_start` 遗物。此次证明的是这六件的可见数值与只触发一次；**未证明原作开战队列的精确相对顺序**。Innate、起手生成、混乱抽牌等组合须有原作构建/观察后处理，不能把总手牌数相同当作队列等价。
- `Run.play` 在整张牌的解释器完成后检查胜利，再处理战后遗物。最后一击后的卡牌抽牌 / 卡牌回血与反刺相对顺序，须由卡牌规则核对共同覆盖；本切片不改效果解释器。尤其 [Thorns/Update History](https://slay-the-spire.fandom.com/wiki/Thorns) 记载 Reaper 的回血应先于反刺，已向卡牌任务报告，不能视为本切片已修。
- 药水入口只允许战斗玩家回合；无效槽位、无目标、未知定义、溢出均回滚不耗物，见 `inventory.lua`。成功后消费一次，末敌击杀立即结算。满槽拒绝领取见 `nodes.lua`，但库存用 `table.remove` 压缩槽位；原作槽位身份 / 空槽填补须补原作证据并联动战斗与节点 UI 后处理，未声明一致。
- 未纳入 Sacred Bark、Magic Flower、Toy Ornithopter、Artifact 等修正规则，不得以这份首发账本推断其已经支持。现有 7 件遗物本身不包含这些项目。
- Poison Potion 角色获取差异属于 TASK-13.1；此处只验证取得后的对象、数值与 tick。
- 原作构建号、原作观察截图/录像、千星平台编译、候选 hash、副本导出、官方导入、实机显示和操作均未完成；此次没有打开原神、调用 MCP 或写入存档。

## 验证入口

```powershell
npm run build:data
node scripts/test-lua.mjs tests/lua/inventory_parity.lua
node scripts/test-lua.mjs tests/lua/statuses.lua
npm run check
```

固定种子 42；0 攻击用例将单个敌人的动作替换为明确的普通单/三段攻击，只为隔离反刺契约，不声称该动作是原版 Cultist AI。遗物/药水本身仍用正式 JSON。全部平台验证保留待办。
