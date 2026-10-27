# 第三幕 Writhing Mass 来源切片

TASK-62 的 A0 普通遭遇新增 Writhing Mass，沿用原 TheBeyond 队列和权重；不替换、裁剪或补抽其它遭遇。其余未实现内容仍明确拒绝。本片没有官方导入、原版二进制、实机或自然三幕通关证据。

行为依据是社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。17 个读取文件的固定 Git blob、SHA256、方法及独立模型输入摘要见 [source-lock](../../tests/fixtures/act3-writhing-mass-source-lock.json)。原 Java 只保留在仓库外研究证据目录，不进入产品；没有核对中文敌人名，显示来源名称。

## A0 合同

| 来源 | 实现与验证边界 |
| --- | --- |
| `WrithingMass` constructor、`AbstractMonster.setHp` | 160 HP；显式 `setHp(160)` 仍消费一次 monsterHpRng。开场消费一次 0..99 AI 抽样：0–32 三连击、33–65 攻防、66–99 攻击削弱。 |
| `takeTurn` | 重击 32；三次各 7；攻击 15 后固定格挡 15；攻击 10 后依次虚弱 2、易伤 2；Implant 永久获得一张 Parasite。每种动作末排队 RollMove。 |
| `getMove`、`Random` | 后续基础区间 0–9/10–19/20–39/40–69/70–99；保留所有历史重选、次级整数区间及 binary32 的 .1/.4/.3 概率抽样。历史是最近一次选出的动作，包含应激重选，不是最近执行动作。Implant 只在实际 takeTurn 时标记已用，宣布后被应激改掉不消耗。 |
| `MalleablePower.onAttacked`、`ReactivePower.onAttacked` | 只对有来源、正数、非致命 NORMAL 格挡后伤害触发。沿用 priority 5 韧性先加入 BOTTOM 格挡并立即递增下一次量，再由 priority 50 应激加入 BOTTOM 重选；不在多段攻击之间提前兑现。固定伤害、THORNS、HP_LOSS、无来源、完全格挡和致命伤害不触发。 |
| `MalleablePower.atEndOfTurn` | 怪物自身回合结束重置为 3；复用既有共享实现，不在玩家回合开始另加重置。 |
| `RollMoveAction`、`GainBlockAction` | 应激重选没有死者来源保护：有队友存活时照常重选，格挡动作拒绝死者；最终敌人死亡则既有队列清理取消重选。 |
| `AddCardToDeckAction`、`ShowCardAndObtainEffect`、`Soul.obtain` | Parasite 仅进入永久卡组，使用独立永久 UID，不进入本场手牌、抽弃消耗堆，不消费战斗牌 UID 或牌随机。下一场构造才复制进战斗。 |
| `Omamori`、`CeramicFish`、`DarkstonePeriapt` | 御守先抵消诅咒并减充能，早于 UID、永久插入和获得牌遗物。未抵消时按持有顺序执行陶瓷鱼 +9 金和黑石护符 +6 生命上限。即使被御守阻止，Implant 本战仍已使用。 |
| `AbstractCreature.increaseMaxHp/heal` | 显式、同一 owner 的战斗适配使用既有 `Inventory.apply(increaseMaxHp)`：先增加上限，再按战斗治疗修正立即治疗，发治疗事件并调用 HP 改变 hook。保留魔法花、印记禁疗、红头骨和原创角色治疗路径；这不是伤害/复活动作，不消耗瓶中精灵。普通未适配 `Run.obtainCard` 的战斗黑石拒绝边界保持。 |
| `Parasite.onRemoveFromMasterDeck` | 沿用真实永久移除 API，移除一次降低 3 上限；战斗消耗不调用此 hook。 |

## 永久所有者与事务

只有包含此敌人的战斗新增 `nextMasterDeckUid`。普通 `masterDeck` 仍为原独立副本，非 Writhing 战斗不增加该字段。`Run.commitCard` 同步此战斗的外部永久获得与御守结果，避免合法 active-combat 获得使后续 Implant 的 UID 或遗物计数过期。

敌人动作只写战斗私有的永久获得清单。成功的 Run 命令一次提交到永久卡组，并同步获得牌造成的血量/上限；不会再次调用获得牌遗物。失败恢复整个既有图和原对象引用。原生出牌快照补存 AI 随机状态，保证排队应激重选后异常也回滚随机原始字与计数。

## 验证

- `node --test --test-concurrency=1 tests/act3-writhing-mass.test.mjs`：19 组 Lua 行为及独立向量可重建检查。来源模型为三个种子各 32 次后续选择，逐次核对完整 RNG 状态及整数/浮点抽样数，不读取产品 Lua/data，也不是 PC 执行 oracle。
- seed 34 的真实 `Run.startRoomCombat` 在保留原队列前两项后进入此单怪遭遇，证明正式接线和一次 HP/AI 消耗；这是显式章节边界 fixture，不模拟此前两幕胜利。
- Twin Strike 真实多段出牌覆盖原生/实验调度，断言所有伤害后才兑现韧性与应激；两种调度的迟发重选异常恢复 actor、pile、AI RNG 及 primitive 原别名。
- 永久诅咒覆盖御守 2/1/0、陶瓷鱼、黑石、魔法花、印记禁疗、异化、红头骨、瓶中精灵保持、外部 Run 获得、下一场复制、永久移除和晚期 hook/提交/御守失败回滚。
- 相邻回归包括既有 Act2、Orb Walker、Shapes、Maw/Growth、Transient、基本诅咒和普通遗物；完整 CI 与合入 SHA 由父组合另验，不以本片定向绿灯替代。

新增核心模块与两条仅运行时的遗物/Inventory 回调已登记 architecture。原生意图投影增加永久诅咒说明；没有新控件、布局、桌面输入或平台能力声明。
