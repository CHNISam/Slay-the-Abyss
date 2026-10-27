# 自然四房构筑回归改用完整来源奖励池

本切片基于冻结`6152bb7`，只迁移自然路线测试的输入和观察向量。完整来源奖励池各有71张非基础牌；当前可执行Profile定义仍是Defect56、Silent61，不把尚未实现的卡从奖励池删除，也不借用其他分支的新定义。

未修改的原fixture已先证红：Defect种子5首奖实际为`barrage,hologram,ball_lightning`，旧受限池预期`consume,cold_snap,reinforced_body`；Silent种子9首奖实际为`backflip,dodge_and_roll,quick_slash`，无原路线要求的毒牌。旧角色、首房生命与战斗断言先通过，失败发生在奖励身份边界。首次原脚本分别耗时1.47秒、2.62秒。

筛选先使用现有`tools/sts1-card-rng-oracle.py`的独立64位随机解释器，以及固定319009来源`data/reference/sts1-card-pools/registration.json`的370项事实和`pools.json`的独立HashMap遍历顺序。registration文件SHA256为`c782f0e0eab61bc59e599b645e5d5b5f9ea348b7a59d819b2789e125a4b65580`。按BLUE/GREEN及COMMON/UNCOMMON/RARE筛完整奖励桶；每奖逐槽执行稀有度抽样、偏移更新、原桶身份抽样与重复拒绝，最后消费非稀有牌的升级抽样（第一幕概率0仍消费），连续生成四次正常奖励。该解释器不导入生产Lua或修改Run。它也精确重现上述两个旧种子的实际首奖，因而确认是池迁移，而非用新观察值掩盖战斗失败。

搜索范围1–200000，没有运行Lua种子矩阵。源初始稀有度偏移5意味着第一房的三个奖励都不可能为稀有，旧电动力首奖路线必须迁移到第二房公开领取；不能重抽或裁池来保留旧种子。

| 路线 | 新种子与真实领取顺序 | 四房后观察 |
| --- | --- | --- |
| Defect集中/霜球/循环 | 1318：defragment → loop → cold_snap → sweeping_beam | HP25；集中霜球格挡3次；循环额外被动2次，均造成真实伤害；第五房开场检查状态清零 |
| Defect电动力群体闪电 | 29045：chill → electrodynamics → claw → steam_barrier | HP51；电动力2次、冰寒3次；群体闪电相关动作7次，其中实际多目标2次；第五房开场检查状态清零 |
| Silent毒刺/灾祸 | 177136：poisoned_stab → finisher → bane → storm_of_steel | HP61；毒刺5次且5次实际施毒，灾祸实际双段1次、总伤害11；Finisher/Storm只领取，不宣称使用 |

独立解释器只提供完整池奖励身份与种子筛选依据。HP、回合、行动次数、房间组合后的效果计数以及最终状态是本项目冻结代码真实重放的**观察向量**，不是原版PC运行或独立原版战斗oracle。诊断回放与最终测试均通过`Run.new → Run.startRoomCombat → Run.play/endTurn/chooseDiscard → 胜利 → rewardOptions/claimCardReward/claimGoldReward/leaveCombatRewards`，没有改写HP、能量、牌组、敌人、状态、RNG或offers。

保留全部原断言：Defect的27处`assert`均在，`eq`调用点（不含函数定义）由78增至81；Silent的36处`assert`均在，新增完整71池和每次永久UID只分配一次两处检查。角色初始生命/牌组/遗物、跨房HP、Source编队、房内随机计数、实际构筑事件、四房精确offers与领取、状态重置及Silent同种子完整状态签名二次重建均继续验证。只更新已失效的种子和精确观察值；三个路线都是真实连续四胜。

两个正式fixture按原默认30秒预算串行通过，未改超时、runner或断言数量。该基线没有`watcher_natural_build.lua`；现有Watcher attack/flow/retain文件是直接Combat机制fixture，不通过临时构建第五种脚本冒充已有自然路线已验收，故本片未改它们。

边界保持原样：领取后仅`floor += 1`是明确的房间入口测试快捷方式，未验证Map导航、Neow/商店等额外随机消费、全幕自然通关、平台导入或实机；上述成果不等于M3自然/平台验收完成。无生产、Backlog、静态基线或前台操作改动。
