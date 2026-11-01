# TASK-16：Iron Wave 先格挡后攻击的顺序回归

2026-10-23，从 `origin/develop` 的 `7d809f3` 独立核对。适用目标为初代 Slay the Spire PC 正式版 A0。

**没有发现当前卡牌的顺序错误。** `data/cards.json` 的 `iron_wave` 基本版已是 `block 5 → damage 5`，升级版为 `block 7 → damage 7`；旧基线 `a6be1b6` 也相同。`traveler.zh-CN.json` 与批准原型均明确先格挡后攻击。此次只增加独立来源回归，不制造生产数据或通用战斗算法改动。

## 来源及可信度边界

读取固定提交 `fc379c875c11e008e9c10548ac8e394c301c532f` 的第三方 Jad 反编译镜像：

- [IronWave.java · 构造、use、upgrade](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/red/IronWave.java#L26-L49)：基本费用 1、伤害和格挡均 5；`use` 先把 GainBlockAction 入队，再加入等待/视觉动作，最后 DamageAction；升级将两项各增加 2，费用不变。读取本地下载原文逐行核对，没有执行镜像或复制实现。
- [CardCrawlGame.java · 版本字段](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404)声明 `V2.3.4 / 2022-12-18`；这只是镜像字段，未与正版 PC 二进制 hash 交叉验证，**不构成构建真实性保证**。
- 反刺每段普通攻击触发（包括 0 伤害）、不受攻击修正且先消耗攻击者格挡，证据与剩余核验边界沿用 [TASK-14.1 账本](TASK-14.1-inventory-parity.md)。此次不宣称新增原作实测。

查阅日期为 2026-10-23；原作实际观察日期、录像、正版构建 hash 尚缺。千星平台编译/副本导出/官方导入/实机均未运行。TASK-16 的逐卡全池与平台 AC 保持未勾选。

## 可区分顺序的固定预期

`tests/lua/iron_wave_order.lua` 直接经 `Combat.play` 使用正式 JSON 的 Iron Wave 单牌，种子 42；以 Jaw Worm 作为目标容器，只在夹具里设定生命、格挡和 Thorns，不执行敌方 AI。不以这些夹具声称自然构筑或完整通关证据；自然获取/升级链路仍由既有 `card_pool.lua` 覆盖。

| 输入（基本 / 升级） | 固定预期 |
| --- | --- |
| 玩家 80 HP、无格挡；敌 100 HP、Thorns 3 | 玩家仍 80 HP，余格挡 2 / 4；敌 95 / 93 HP |
| 玩家 1 HP、无格挡；末敌 1 HP、Thorns 3 | 敌死亡；玩家仍 1 HP，余格挡 2 / 4，胜利而非同时死亡 |
| 玩家 3 HP、无格挡；敌 Thorns 10 | 新增格挡先吸收 5 / 7，再失去剩余 3 HP，失败；已完成攻击伤害 |
| 玩家 Strength -100，攻击归零；敌 Thorns 3 | 敌生命不变；仍先获得格挡，吸收反刺后余 2 / 4，玩家不掉血 |
| 敌 100 Block、Thorns 3 | 敌不掉血、Block 95 / 93；反刺仍发生，玩家余 Block 2 / 4 |
| 玩家 Dexterity 3、Frail 1；敌 Thorns 6 | 先获得 6 / 7 格挡，再承受反刺；玩家不掉血，余 Block 0 / 1 |

12 例还验证费用恰为 1、牌实例进入弃牌堆且不消耗，以及实际事件帧中 Block 已提交，随后才攻击与反刺。没有从 `effects` 数值动态生成预期。

## 受控变异证明

正常数据首先通过 12 例。然后只在一个 Lua 测试进程的 `abyss_data` 内存表中交换 Iron Wave 基本和升级的前两项效果，模拟错误的 `damage → block`；不写 JSON，不改解释器。使用相同测试，**12 例全部失败，进程退出 1**：常规反刺用例玩家实际 77 而非 80；1 HP 末敌用例玩家死亡而非存活；致死反刺用例实际吸收 0 而非 5 / 7。退出该进程后，正常数据再次 12 例通过。

离线复现入口：

```powershell
npm run build:data
node scripts/test-lua.mjs tests/lua/iron_wave_order.lua
npm run check
```

本切片的红绿证据来自受控变异，不是修复前生产缺陷。完整门禁结果记录于 TASK-16 CLI notes；不能将本卡顺序核对推断为其他 29 张牌或整个 PC 算法已一致。
