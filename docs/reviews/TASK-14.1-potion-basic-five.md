# 五种基础药水的真实库存效果

2026-10-25，基线 `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`，复用 TASK-14.1 / TASK-13.1。改动限于五瓶定义、对应中文名/说明与现有瓶图标、两处旧获取选择器的过渡排除、首发清单排除项及专项用例；没有修改 Run、库存执行器、Combat、Actor、地图或任务正文。

固定源为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的本地 zip。[来源条目](../rules/evidence/sts1-potion-basic-five.json)记录13份文件的 SHA256 / Git blob；这是社区反编译镜像核对，不是官方源码、正版 PC 二进制认证或 PC 实测。没有复制 Java 方法体。

| 原瓶 / 项目 ID | 稀有度 | 对象 | A0效果与现有执行器 |
|---|---|---|---|
| Swift Potion / `swift_potion` | Common | 自己 | `draw` 3；`SwiftPotion.java` 19/33/38行 |
| Weak Potion / `weak_potion` | Common | 选定敌人 | `applyStatus` 虚弱3回合，sourceIsMonster=false；`WeakenPotion.java` 22/38/43行 |
| FearPotion / `fear_potion` | Common | 选定敌人 | `applyStatus` 易伤3回合，sourceIsMonster=false；`FearPotion.java` 22/38/43行 |
| Ancient Potion / `ancient_potion` | Uncommon | 自己 | `gainStatus` Artifact1；`AncientPotion.java` 23/38/46行 |
| LiquidBronze / `liquid_bronze` | Uncommon | 自己 | `gainStatus` Thorns3；`LiquidBronze.java` 24/39/47行 |

五瓶均沿用 AbstractPotion 的战斗使用限制，执行当前药效后由真实 `Run.usePotion` 一次消费原槽，不花能量、不改永久牌组UID。虚弱/易伤增加持续时间，不增加减伤/增伤百分比；首次玩家施加在本轮末即减一，Artifact阻挡仍属于成功用瓶。Ancient可叠加，每个减益消耗一层；Liquid Bronze可叠加，本战持续，在完全被格挡的普通攻击上也反击，反击不触发递归荆棘。Swift沿用既有 DrawCardAction边界：手牌上限10、No Draw不抽但用瓶成功、牌堆全空不扣“疲劳”血；跨堆时每次 EmptyDeckShuffleAction都消费原shuffle流，包括请求多于剩余牌数时最后一次空堆shuffle。

## 获取隔离与后续必须移除的过渡项

本片没有把这五瓶加入正常受限桶。五瓶明确标为 `acquisitionPending=true`，`abyss_shop.lua` 的 potions候选和 `abyss_potion_rewards.lua` 的旧选择器仅增加这一排除；原有候选ID、排序、价格、RNG消费与掉落修正不变。`launch-content.json`将五瓶列入带原因的 exclusions，正常可获得数仍为6。它们可通过正式 `Run.obtainPotion` → `potionView` → `usePotion` 执行已实现药效，不是正常随机获取已完成的声明。

**完整33种原池接入时，必须移除这两个过渡排除，并接固定源顺序/完整池拒绝采样。正式源池不能跳过 pending/unsupported项、改稀有度、删候选或用新的桶概率掩盖缺项。** 先前[33种目录](TASK-14.1-full-ironclad-potion-pool.md)的“已实现6/缺27”为其原基线覆盖快照，本片新增五种基础效果不代表余下22种或其依赖已齐。

## 定向验证与保留边界

`tests/potion-basic-five.test.mjs`运行3项JS测试及两份独立Lua夹具共12组断言，每份沿用默认30秒预算。所有五瓶均由真实Run库存入口获得、查看、使用；验证非首槽消费/邻槽不变、预览无副作用、重复用瓶拒绝、选择第二敌人、目标死亡/逃跑/非法输入、阶段拒绝、溢出拒绝及整个Run值/关键表身份不变。药效覆盖抽3张实际UID、9/10张手牌、空堆、实打Battle Trance的No Draw、洗牌双次消费、新施加/叠加回合递减、Artifact阻挡、Ancient与Thorns叠加。

另以16个种子对比“旧7定义”和“新增五瓶但pending”商店整库存及每种子12次连续掉落，逐结果、RNG状态、modifier一致；去掉pending的反向用例实际能在商店和掉落中抽到全部五瓶，保证过滤不是无效断言。日志、红绿结果及其他定向回归见来源条目的 verification。

数据校验、主题生成和首发清单门禁均单独运行。未做 full check、GUI、平台构建/导入/实机、push或merge。Sacred Bark的potency翻倍、未来用药遗物钩子及完整33池消费仍未实现/认证；本片不把它们纳入通过结论。任务整体AC保留，父线统一接完整池和组合验收。
