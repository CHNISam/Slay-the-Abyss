# 完整75卡验收矩阵

完整75张为正式交付目标，不缩减为30张。当前为完整实现候选，**严格验收尚未完成**。

冻结运行源：`529c8af1c2fd0bc6d501260824b04eb6f18821ee`，已整合本轮读取的develop `7f11cc2`。机器矩阵：[matrix.json](../evidence/warrior75/matrix.json)，固定来源与规则事实：[sources.json](../evidence/warrior75/sources.json)。每张记录原方法行段、SHA256/Git blob、共用实现入口、合法渠道和剩余缺口；第三方源码仅存忽略目录，不进入交付。

本地证据入口：`node scripts/verify-warrior75.mjs <新输出目录>`。同源八组专项全部通过：150个逐卡普通/升级独立数值执行、6组原始消耗组合、39组边界/顺序、独立洗牌、7组获取契约、75个公共获取→营地升级→下一战事务、真实控件树UID选牌、160种完整卡面文字及Courier独立熵/失败原子性。渠道测试显式布置导航前缀与足额金币，保留真实库存/价格/购买/UID，不冒充自然流程通关。

完整CI [40129254276](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40129254276)正在运行，呈现作业通过；整体尚未通过。上一轮完整CI因卡名高度38低于既有40单位门禁失败，已修正为40并保留原断言，布局7项通过。更早的菌兽超时保留900个决策断言，改为复用目录、逐例独立重置后约2.5秒；每色虱虫800决策同样保留，约3.4秒。不提高超时或用专项替代全量门禁。

正式候选SHA256 `0ed96e096502a3b46513080899bfb23dc4929143eebe6a77d99d823fe0a659b2`，52模块/2391控件/max59子节点逐项读回同源，静态0错34警告；尚未官方导入。另建独立诊断副本，实际运行逐卡与顺序专项并验证奖励文字、Searing Blow重复升级和消耗选牌；其显式牌组/导航状态不算自然获取，当前正在启动，没有提前记通过。

[真实普通战斗历史证据](../evidence/warrior75/normal-a891451.json)：a891451候选在官方存档1073741853正常击败两只原数值软泥，观察Strike6、Bash8及易伤后的Strike9、脆弱下Defend3，领取Wild Strike并回到地图（牌数10→11）。本轮64条新打印、ready、胜利与截图均已保存；没有打下一战或验证Wild Strike的Wound效果。该候选发现长卡名/效果裁切；后续修复必须在新候选另验。单场胜利和菜单不能算75张逐卡通过。

72张红池身份顺序、原奖励cardRng/稀有度偏移和房间洗牌已有源契约及本地证据；Courier身份已接独立会话熵，详见[专项依据](TASK-16-warrior75-courier.md)。原作外部随机历史、正版PC构建身份、逐卡实机与整套UI门禁仍未验收，全部卡牌严格状态保持pending。

| 卡牌 | 稀有度 | 基础/升级费用 | 数据 | 代码 | 本地基础/升级 | 平台实机 |
|---|---|---|---|---|---|---|
| Strike | basic | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Defend | basic | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Bash | basic | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Anger | common | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Armaments | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Body Slam | common | 1/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Clash | common | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Cleave | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Clothesline | common | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Flex | common | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Havoc | common | 1/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Headbutt | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Heavy Blade | common | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Iron Wave | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Perfected Strike | common | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Pommel Strike | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Shrug It Off | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Sword Boomerang | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Thunderclap | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| True Grit | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Twin Strike | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Warcry | common | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Wild Strike | common | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Battle Trance | uncommon | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Blood for Blood | uncommon | 4/3 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Bloodletting | uncommon | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Burning Pact | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Carnage | uncommon | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Combust | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Dark Embrace | uncommon | 2/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Disarm | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Dropkick | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Dual Wield | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Entrench | uncommon | 2/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Evolve | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Feel No Pain | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Fire Breathing | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Flame Barrier | uncommon | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Ghostly Armor | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Hemokinesis | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Infernal Blade | uncommon | 1/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Inflame | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Intimidate | uncommon | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Metallicize | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Power Through | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Pummel | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Rage | uncommon | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Rampage | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Reckless Charge | uncommon | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Rupture | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Searing Blow | uncommon | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Second Wind | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Seeing Red | uncommon | 1/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Sentinel | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Sever Soul | uncommon | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Shockwave | uncommon | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Spot Weakness | uncommon | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Uppercut | uncommon | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Whirlwind | uncommon | X/X | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Barricade | rare | 3/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Berserk | rare | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Bludgeon | rare | 3/3 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Brutality | rare | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Corruption | rare | 3/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Demon Form | rare | 3/3 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Double Tap | rare | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Exhume | rare | 1/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Feed | rare | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Fiend Fire | rare | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Immolate | rare | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Impervious | rare | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Juggernaut | rare | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Limit Break | rare | 1/1 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Offering | rare | 0/0 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |
| Reaper | rare | 2/2 | 已定义 | 候选待完整复审 | 基础执行已过/已过 | 未验 |

仍缺：原版随机流和获取概率完整验收、全部集成回归、同一候选构建/导入与75张逐项自然实玩证据。所有最终验收项保持未勾；不得据此宣称75张严格复刻完成。
