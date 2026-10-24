# 战后药水与正常路线账本

2026-10-24，承接 TASK-12.3 / TASK-17.3。原基线 `3bd3afa` 的战后奖励只有金币和选牌，生产代码没有调用 `Run.obtainPotion`；在途 PR163 已实现正常商店买药，本切片复用该入口，补战后来源。

## 规则与边界

本轮重新读取仓库既有固定镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`：

- [AbstractRoom.addPotionToRewards 与战后调用位置](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/rooms/AbstractRoom.java)：初始掉落概率为40%，本局修正初始0；整数0–99严格小于40+修正时掉落。出现掉落，修正减10；未掉落，修正加10，不人为截断。普通和精英相同；第一幕Boss也调用。已有至少4条奖励时概率置0。新幕重置属于后续多幕功能。
- [AbstractDungeon.returnRandomPotion](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/AbstractDungeon.java) 和 [PotionHelper](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/helpers/PotionHelper.java)：药水稀有度65%普通、25%罕见、10%稀有。Ironclad池排除Silent专属毒药水。

镜像是方法规则证据，不认证正版PC构建。没有复制或执行其代码；项目独立实现。下载副本在本工作树 `.artifacts/source-potion/`，不部署原作源文件。

`abyss_potion_rewards` 只准备药水事务，`Run.finishCombat` 提交一次，保持原有金币/卡牌规则。战后和PR163商店共用 `run.shopRng.potion` 的连续流；战斗LCG与事件流不被药水抽取污染。旧局首次缺少该字段时从原始局种子建立，随后同局继续消费。`Run.new` 重置修正、流和库存。

受限内容明确保留：当前普通药水只有火焰/格挡/力量/敏捷/能量五瓶，罕见只有再生一瓶，稀有零瓶。稀有桶抽中时生成标记 `unavailable`，UI显示未实装；不得重抽为普通药水、宣称完整药水池，或把缺失条目当作真正获得。原作从全池反复抽取直到稀有度匹配；项目从受限同稀有度桶排序抽取。因此保留稀有度概率，但**完整内容顺序、拒绝抽样耗随机量和原版同seed轨迹未认证**。

## 玩家事务

- 奖励页显示药水名，提供“领取药水”和“放弃药水”。领取放入最左空槽；重复领取/放弃被拒绝。
- TASK-52修复：选牌和跳卡不再领取药水；有瓶的普通战后保留独立奖励页，领取/放弃与前往地图分开。满槽只拒绝药水领取，不阻止选牌，提示可从顶部药水槽丢弃旧瓶再领取；待处理瓶子阻止离开，不能静默吞掉。固定来源重读、近邻差异和验证边界见[TASK-52](backlog-details/TASK-52.md)。
- 缺内容的桶不授予药水；玩家可放弃，也可选牌继续。Sozu通过 `Run.obtainPotion` 的统一限制拒绝，不能绕过。
- 药水奖励按钮沿用已有四态按钮与输入归属令牌，旧局/旧奖励指针不能消费新奖励。位置和字号来自共享主题。

## 可复现离线入口

先构建数据、主题与UI，再执行：

```powershell
node scripts/m2-resource-evidence.mjs --seeds=42,36,1,2,3 --stop-after=16
```

脚本使用原始80生命、99金币、10张初始牌、原敌人生命和战斗数据；所有换房间只走 `Nodes.available/enter`，战斗只走真实 `Run.play/endTurn`。没有直接写生命、金币、卡组、地图楼层，没有调低敌人生命，没有注入药水。逐房间记录血量、金币、永久卡组UID/升级、遗物、物理药水槽、事件与商店随机状态；重复领取/推进拒绝检查资源和导航不变。重开通过新的 `Run.new` / `Map.generate` 与最初状态逐值比较。

`scripts/m2-autoplay-policy.lua` 是独立只读测试资产，不在生产模块目录。暴露 `chooseCombat(run) → uid,target,details`、`scoreCard`、`chooseReward`、`chooseNode` 与 `suggestNodeAction`。它只读取当前手牌、当前意图和公开节点描述，不读取未来抽牌顺序或未来随机结果。证据包含每步命令前的手牌位置/数量、卡牌UID、目标位置/敌人数、能量和命令结果，便于测试副本或实机重放。

首次旧商店基线+本切片药水的离线试跑：seed42/36/3实际打赢16层Boss，分别剩18/21/8生命；seed1死于Boss，seed2死于5层。固定停止于16层，不能称17层通关。seed42连续路线包含七类房间、营地回血和升级、购卡和删牌、事件、普通宝箱、药水领取与多场真实战斗；不等于PR163组合源或平台候选已验证。完整原始账本为该工作树 `.artifacts/m2-resource/evidence.json`，后续同名文件会被显式重跑覆盖，最终使用固定源记录需另存。

## 尚待验证与已知缺口

1. 原精英战后尚缺遗物掉落，主线程已确认记录到TASK-13.1/M3，不把药水修复写成完整原版奖励一致。金币/卡牌抽选也沿用既有规则，未在此扩大审计。
2. 已在组合源 `f0a1a8f`（合入主线程 `f9ba083` 的商店与Boss）重新跑完整17层，保留小量审计脚本修正的dirty清单。seed3正常胜利25生命/105金币，seed42正常胜利34生命/131金币；seed36于16层正常战败，0生命/135金币。全部使用受限有限货架、正常药水共享流和合法Boss宝箱领取；没有注入、补血、作弊金币、改敌人或地图绕路。原始完整证据独立保存 `.artifacts/m2-resource/integrated-f0a1a8f.json`，SHA256 `5bd26029ba61047bf9cc1d4401ba8dc59c42203197027730be0b966ff08b2e88`，不覆盖此前旧基线失败/胜利文件。
3. 真实平台导入、当轮ready/日志/截图、逐节点药水与资源账本、失败后平台重新挑战、官方胜利结算和UI验收均未由本离线脚本证明。没有启动GUI/MCP或发布。

验证入口：`tests/lua/potion_rewards.lua`（概率边界、正常/精英/Boss、满槽拒绝、领取/跳过/重复、缺内容、新局重置和共享流）及 `tests/lua/battle_ui_potion_rewards.lua`（真实生成树显示/满槽操作/旧奖励指针）。已有Run和UI相关回归同时保留。

组合源的正常seed3路线：`f1_l1 → f2_l1 → f3_l1 → f4_l1 → f5_l1 → f6_l2 → f7_l2 → f8_l3 → f9_l3 → f10_l3 → f11_l3 → f12_l3 → f13_l3 → f14_l3 → f15_l3 → f16_l2 → f17_l2`。该路线覆盖七类房间、两种营地动作、购卡、事件、普通/首领宝箱及自然药水；seed42补正常删牌，seed36补正常买药，随后真实战败。三局都验证新局状态重置，不能以跨种子覆盖替代同一候选的实机证据。
