# TASK-14.1：首发药水方法体与固定槽位

2026-10-23，基线 `e47bfcf`，目标为初代 Slay the Spire PC 正式版 A0。未开启原神或原作，没有平台编译、存档写入或实机验证。查阅日期不等于原作观察日期。

## 七件药水核对

逐项读取第三方 Jad 反编译镜像 `purewhitelove/ButterflyGame` 固定提交 `fc379c875c11e008e9c10548ac8e394c301c532f` 的构造、`getPotency`、`use`。其 [版本字段](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404)声明 V2.3.4 / 2022-12-18，但未核对正版 PC 二进制 hash；镜像不是官方开源代码，版本真实性仍待核实。只读方法体并转述行为，没有复制实现或执行镜像。

| 当前 id / 固定来源方法 | 基础量、对象与持续期 | 本次结论 / 边界 |
| --- | --- | --- |
| `fire_potion` / [FirePotion.java:40–49](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/FirePotion.java#L40-L49) | Common；所选一个敌人，20 点 THORNS 类伤害，执行目标侧修正 | 当前 JSON 已是 **20**；12 属于 Block Potion，没有需要改为 20 的错误值。保留现有固定非攻击伤害及穿格挡后扣血测试；目标侧未纳入能力不因此视为支持 |
| `block_potion` / [BlockPotion.java:38–45](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/BlockPotion.java#L38-L45) | Common；自己获得 12 Block | 当前 12 正确；直接将 potency 传入 GainBlockAction，不套牌的 Dex/Frail。格挡下回合普通清除/999上限已有回归 |
| `strength_potion` / [StrengthPotion.java:40–49](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/StrengthPotion.java#L40-L49) | Common；自己增加 2 Strength，非 Flex 式回合结束移除 | 基础量与本战持续期正确；共享 Strength 上下限仍不一致，见下文 |
| `dexterity_potion` / [DexterityPotion.java:41–50](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/DexterityPotion.java#L41-L50) | Common；自己增加 2 Dexterity，非 Speed Potion 式临时敏捷 | 基础量与本战持续期正确；共享 Dexterity 上下限仍不一致 |
| `energy_potion` / [EnergyPotion.java:36–43](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/EnergyPotion.java#L36-L43) | Common；本回合获得 2 Energy | 当前基础量正确，不支付能量、不作为出牌，不改变其他瓶的位置 |
| `poison_potion` / [PoisonPotion.java:40–47](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/PoisonPotion.java#L40-L47) | Common；给所选一个敌人施加 6 Poison | 当前基础量与对象正确；目标回合 tick/末敌击杀见既有库存回归；Silent 专属获取仍属于获取池任务 |
| `regen_potion` / [RegenPotion.java:40–48](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/RegenPotion.java#L40-L48) | Uncommon；自己增加 5 Regen | 当前基础量正确；[RegenPower.atEndOfTurn](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/RegenPower.java) 调用 [RegenAction.update](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/unique/RegenAction.java)：仍在战斗且存活时先 heal、再将玩家层数减一。双瓶叠加、回合结束与战斗结束不补 tick 已有回归 |

[AbstractPotion.canUse:856–860](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/potions/AbstractPotion.java#L856-L860) 要求战斗阶段、未结束玩家回合、存在未死亡敌人；[PotionPopUp.updateInput / target update](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/ui/panels/PotionPopUp.java#L217-L265) 在成功使用后通知遗物并消费对应 slot。现有七件都是战斗用药水；本轮保留真实 Run 入口的阶段/目标拒绝，不为仅人工篡改生命与阶段的不可达状态增加调度守卫。

## 已证实并修复的差异：消费后槽位压缩

原版固定槽位的证据链：

1. [AbstractPlayer 初始化](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/characters/AbstractPlayer.java#L280-L286) 为每个位置建立 `PotionSlot` 占位。
2. 原固定镜像没有 TopPanel 文件，未靠记忆补齐。交叉读取另一份固定镜像 [`aeubanks/sts@319009d.../TopPanel.destroyPotion:517–519`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/panels/TopPanel.java#L517-L519)：把被消费位置替换为空槽，保留其他索引。其 [版本字段](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java#L112-L113)同样声明 2.3.4，仍不是二进制真实性保证。
3. [AbstractPlayer.obtainPotion:2667–2709](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/characters/AbstractPlayer.java#L2667-L2709) 扫描最左空槽，在原索引填入；满槽返回 false。指定槽位的重载也是原位替换，不挪动其余瓶。

旧 `Run.usePotion` 用 `table.remove`，使用中瓶会使右侧瓶左移；旧战斗 UI 虽在本场缓存物理按钮映射，库存本身、下一战、补货和节点计数仍不正确。现在消费仅清空对应位置，库存是按槽号索引的稀疏表；`Run.potionView` 保留同样的空位，`Run.potionCount` 显式数有效槽，调用方不能用 `#` / `ipairs` 推断瓶数或遍历右侧瓶。

新增 `Run.obtainPotion(run, id)` 仅负责已知药水放入最左空槽，满槽/未知 id 原子拒绝，返回实际槽号；它是库存命令，**不代表新的发瓶来源、奖励概率或商店事务**。当前 Cleric/Purifier 替换旧自创药水事件后，尚无自然药水奖励/商店获取链，不得用这个命令的测试声称自然 claim 已完成。

战斗 UI 按真实物理槽绑定和显示，消费不移动其他按钮；同一场补入中槽后对应按钮刷新。节点 UI 使用有效瓶数，首槽为空也正确显示如 `1/3`。

## 红绿与验证

`tests/lua/potion_slots.lua` 的六组经真实 `Run.startCombat/usePotion/obtainPotion/claimCardReward/endTurn` 入口执行，种子 42：

- 中瓶消费后左右瓶保持，重复用空槽拒绝且不消耗旁瓶。
- 首瓶消费后槽 2 / 3 的视图和命令仍可用；火瓶准确扣 20。
- 从仅槽 3 有瓶开始，补货依次填 1、2；满槽与未知 id 不改变任何 run 字段/RNG。
- 同场消费中瓶再补护盾，仍填中槽；另外两瓶不被替换。
- 稀疏库存的无目标、空槽、越界、非玩家回合和战斗外输入均原子拒绝。
- 中槽火瓶击杀末敌，只消费该瓶、正常战后回复/奖励；槽 3 跨战保留；实际敌方攻击造成失败后不能再用药水，不消耗遗留瓶。

修复前六组中五组失败：中瓶消费后实际为 Regen 而非空槽；首瓶消费后 view[1] 仍非空；末敌击杀后右侧 Regen 移位；另两组缺少原位补货命令。修复后六组全部通过。既有 `inventory.lua` / `inventory_parity.lua` 顺序用药输入更新为真实槽号，数值、回合、胜败等预期保留；新增实际战斗按钮补槽和节点计数回归。

定向执行：

```powershell
npm run build:data
npm run build:theme
npm run build:ui
node scripts/map-ui-layout.mjs
node scripts/test-lua.mjs tests/lua/potion_slots.lua
node scripts/test-lua.mjs tests/lua/inventory.lua
node scripts/test-lua.mjs tests/lua/inventory_parity.lua
node scripts/test-lua.mjs tests/lua/battle_ui.lua
node scripts/test-lua.mjs tests/lua/node_ui.lua
npm run check
```

## 明确保留的差异

- [StrengthPower](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/StrengthPower.java) / [DexterityPower](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/DexterityPower.java) 的 constructor / stackPower 将层数限制在 -999..999。当前共享 actor 允许 int32 累计，故 999 时再喝对应药水会到 1001；此共享状态缺口已通知主线程，未在槽位切片局部绕过统一规则。
- 原作“效果入队、遗物 onUsePotion、销毁瓶槽、之后动作解析”的时序，与当前一次原子提交存在差异；现有七件遗物没有 onUsePotion 钩子，本轮没有新增相关遗物，也未冒称整体队列等价。
- Sacred Bark、Artifact、Intangible 等未纳入修正不因此视为支持；自然获取/掉落/商店链、正版 PC 录像与构建 hash、平台验证均仍待完成。
- 因此完整 TASK-14.1 AC 继续未勾选；这里证明的是基础量核对和固定槽位修复。
