# 完整75卡验收矩阵

完整75张为正式交付目标，不缩减为30张。当前为完整实现候选，**严格验收尚未完成**。

冻结运行源：`505cdb35f59bfd44f4497b61a543c30653ad1512`，整合最新读取的develop `9ae1aec`（正式地图/遭遇、房间HP/AI/洗牌流、手动金币奖励和药水旧输入保护）。逐卡方法、原始SHA256/Git blob、实现入口、四层状态及缺口见[matrix.json](../evidence/warrior75/matrix.json)，固定依据见[sources.json](../evidence/warrior75/sources.json)。不提交第三方源码或素材。

同源本地十组专项通过：150个普通/升级独立执行、6组原始消耗组合、40组边界/触发顺序、独立洗牌、7组获取契约、75个公共获取→营地升级→下一战事务、原生类型的UID选牌控件树、160种卡面文字和Courier独立熵/原子性。来源修正临时费用：回合末重置手/抽/弃牌，排除消耗堆；零费牌跨回合被Exhume取回有真实红绿例。渠道组按基础/普通23、罕见36、稀有16分开，保留全部事务和30秒时限；导航/资金是显式测试前缀，不能冒充自然通关。

完整[Quality40133538883](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40133538883)未通过：Boss奖励旧64种子单文件回放超时。保留1–128每个种子的两次真实构造和全部断言，拆成八个16种子文件；专项均通过，单文件约4–8秒，未放宽30秒时限。完整回归待重跑。历史CI失败保留：文字高度低于40、菌兽/Gremlin Gang超时、只读牌模板新增命中区约束。保留900菌兽/每色800虱虫/1680Gremlin路径及全部构造回滚断言，优化重建和重复图遍历。新命中区默认隐藏，永久牌库不截滚动，仅强制选择启用。

[505cdb3原生诊断](../evidence/warrior75/probe-505cdb3.json)在新官方1073741856运行，试玩前独立读回与外部Lua62/62一致。150个逐卡基础/升级和六组核心专项通过，整轮7/7且无客户端脚本错误。实际点击验证奖励长卡名、Searing Blow+2的21→27预览和永久+3、腐化零费Burning Pact选择Sentinel+后能量6/格挡8/手牌5/消耗2，以及Sentinel先于Pact的UID顺序。该候选有显式库存、能力和导航测试前缀，不能替代正常流程或逐卡自然取得验收。正式候选已构建并审计60模块、2824控件、0错误35警告；新官方导入进行中。

[529c8af原生诊断](../evidence/warrior75/probe-529c8af.json)的旧失败仍保留：消耗选牌曾触发容器不支持AddCursorEventListener的脚本错误，长标题第二行和选择费用未通过，整轮5/7；54/54源码匹配是试玩后核对。当前已通过原生重测的cursorArea命中区、战斗费用和完整标题修复不改写历史结果。

**撤销历史同源归属**：[较早普通战斗](../evidence/warrior75/normal-a891451.json)确有正常数值战斗、胜利和Wild Strike领取画面，但官方1073741853的外部Lua与当时请求a891451仅42/51匹配（8不同、1缺失），不能证明运行该候选。保留原打印/截图及[失败读回](../evidence/warrior75/normal-a891-external-source-mismatch.json)，不把它计作该版本或当前75卡实机通过。后续必须editor_open_map新建存档，先核对独立候选inventory与官方外部Lua，再开启本轮clientScriptLog试玩。

完整72红奖励池、原稀有度偏移、共享cardRng、房间洗牌及[Courier外部熵](TASK-16-warrior75-courier.md)均有固定源与本地契约；原作外部随机历史、逐卡自然实玩、当前选牌修复与整体UI门禁仍有缺口。严格状态全部pending。

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
