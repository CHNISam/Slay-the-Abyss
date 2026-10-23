# TASK-17 深渊守卫攻守阶段与尖刺甲壳

2026-10-23。实现选定首领 The Guardian 的初代 PC Ascension 0 局部规则。未开原神、沙箱或 MCP，未进行平台图编译、存档写入或游戏验证。TASK-17 的完整第一幕、正式胜利、原版一致性与平台 AC 均保留。

## 来源与证据级别

- [社区 wiki / The Guardian / Offensive、Defensive Mode](https://slay-the-spire.fandom.com/wiki/The_Guardian)：初步核对两模式、A0数值和按卡反伤。页面的“立即转形”与历史补丁摘要没有完整动作队列含义，不能据此推导同卡多段中间加格挡或排除所有反刺失血。
- [SlaySpireDB / The Guardian / A0、Moves & intents](https://slayspiredb.com/sts1/monsters/theguardian)：复核240生命和A0动作常数；搜索抓取的条目自称来自最终2022规则集，但本轮直接页面访问返回404，不能将缓存摘录冒充已经取得原版文件。
- [TCK：Slay the Spire Exam v1 解答，2025-08-28 / Problem 1(g)，PDF第2–3页](https://tck.mn/videogame/stsexam/OLD_stsexam1-v1-solu-v1.pdf)：作者直接研究原版结算顺序的测试结果，区分荆棘/尖刺甲壳，表中 Iron Wave 对后者先获得格挡并存活。该表及正文支撑“卡牌自身效果后结算”而非每次命中即刻反伤。不是本项目自己运行原版的实测。
- [Steam玩家原始观察 / Anyone ever die at the same time as an enemy?](https://steamcommunity.com/app/646570/discussions/0/1697167355212601589/) 及 [2021原始反馈](https://www.reddit.com/r/slaythespire/comments/l24bcv/)：交叉确认首领被致死攻击击杀后，已排定尖刺甲壳仍可同时杀死玩家。属玩家观察，可信度低于源码/可复跑原版录像；本轮明确以此实现边界，保留未来原版复验。

进一步只读获取项目地图/商店任务已采用的固定第三方反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`。已实际读到 [CardCrawlGame 1403–1404](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404) 的 V2.3.4 / 2022-12-18 声明；该声明未经正版二进制hash认证，仍不能视为官方源码或原版实测。只读方法体后转述与独立实现，没有复制或运行镜像。关键文件SHA256：TheGuardian `B7F4DAE29ABF4F99373A3A6D71A778E51B030B047ABFCB943E1EBA515AD9C20B`，SharpHidePower `B653EB08D5C63696D827BF6A6B3DAC38CA49636E509EAC63A150D166DFECDB95`。

具体调用链优先于wiki摘要：

- [TheGuardian 42–80、139–199、236–293](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/TheGuardian.java#L236-L293)：A0常数、攻守动作；`damage` 对打开壳时的真实失血累计，没有伤害类型排除；过阈值后将转形追加到队列末尾。进防守递增下次阈值，Twin Slam先排打开壳、再两段伤害、最后移除尖刺甲壳；打开壳动作又把应用模式转换/重置计数排到队尾。
- [TwinStrike 29–33](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/red/TwinStrike.java#L29-L33) 先排两段伤害；[队列114–118](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java#L114-L118) 的 addToBottom 追加到尾部。因此穿过阈值的双击先完成两段，再加20格挡。
- [SharpHidePower 40–46](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/SharpHidePower.java#L40-L46)、[AbstractPlayer 1699–1710](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/characters/AbstractPlayer.java#L1699-L1710) 和 [UseCardAction 31–97](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/utility/UseCardAction.java#L31-L97)：先由卡牌排效果，再在用牌钩子按ATTACK类型排一次THORNS伤害。[DamageAction 68–102](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/common/DamageAction.java#L68-L102) 允许THORNS在拥有者死亡后继续执行；[清理158–169](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java#L158-L169) 保留伤害动作。

真实PC二进制版本、完整动作队列与原版随机算法仍未锁定，不勾选整体原版一致性AC。本首领决策没有随机权重分支；本切片不涵盖其他Boss。

## 可复核契约

| 输入/阶段 | 原版预期与本轮实现 |
|---|---|
| A0开场 | 固定240生命；进攻模式；模式转换预算30；准备9格挡 |
| 进攻循环 | 准备9格挡 → 重击32 → 玩家虚弱2再易伤2 → 旋风5×4；循环 |
| 进攻时实际失血 | 攻击、固定火瓶、中毒和正常荆棘回击均可消耗预算；被格挡吸收部分不计 |
| 预算降至0且首领存活 | 排定防守转换；当前卡牌/敌方动作的既有批次先完成，然后覆盖意图并加20固定格挡 |
| 双击跨越预算 | 两段都先完成，再加20格挡；若后一段致死，排定转换取消，不为死者加格挡 |
| 防守动作 | 收拢：获得尖刺甲壳3 → 滚击9 → 双重打击8×2；并非转形当刻就获得尖刺甲壳 |
| 防守结束 | 进防守时已增加下次预算10（40、50……）；Twin Slam先开壳，攻击后移除尖刺甲壳，再应用预算及重置；下步旋风 |
| 防守时额外失血 | 不累积下一次预算，过阈值的超额失血也不转存；Twin开壳后的少量反刺在动作末重置，但达到新阈值的反刺能排定再次防守 |
| 尖刺甲壳 | 每打出一张攻击牌后只触发一次；多段、群攻、零伤攻击仍按一张牌计数，技能/能力/药水不触发 |
| 尖刺甲壳伤害 | 在牌自身效果之后、最终胜负之前，消耗格挡，再扣生命；忽略攻防修正，不递归触发荆棘；已排定伤害不因首领死亡取消 |
| 首领受到致死阈值伤害 | 不为死者加转形格挡或排新意图；尖刺甲壳造成同时死亡仍判失败且不先发胜利 |

## 实现与独立验证

`data/enemies.json` 新增 `ai.kind=guardian`：预算、增量、即时格挡和阶段意图全部来自数据。独立 `abyss_guardian_ai` 处理攻守阶段；`abyss_enemy_ai` 仅分派策略；`Combat.damage` 与敌方回合毒伤入口沿用上一切片。既有 `actor` 和 `effects` 不作修改。

`Combat.resolvePlay` 在成功攻击牌动作开始时记录具有尖刺甲壳的活敌及数值，牌效果全部完成后结算已排定反伤，再作胜败判定。这样 Iron Wave 的格挡先于反伤，首领死亡也不会取消本次反伤。反伤用独立状态伤害处理，不能误用逐命中荆棘。

阶段、预算及排定转形/返回期间计数均是现有actor的扁平字段，状态计数沿用statuses，出牌错误时由既有事务恢复原引用和全部值。`Combat.applyEffects` 只在当前纳入效果批次完成后排空Guardian转换，非完整复刻原版通用动作队列；未来有插队、自动打牌、异步伤害动作时必须另核。新增状态供真实UI读取，图标复用批准稿壁垒/荆棘资源，没有改布局、字号、颜色或动效。

先新增独立规则测试，旧实现以“初始Mode Shift预期30，实际nil”失败。初版依据wiki的即时多段格挡/反刺排除假设在补读固定镜像后撤回；新红测分别复现反刺预算应27却30、Twin排队重置应40却34、Bash反刺转形后Close Up被错误推进到Roll，修正后24组独立轨迹通过。覆盖完整进攻顺序与数值、30/40/50预算、双击先完成、后段致死取消转换、Twin反刺小额重置与足额再防守、毒、真实群攻/多段/零伤攻击、牌内格挡、同时死亡及回滚。JSON反例覆盖非法引用/预算/缺失状态；真实控件覆盖预算、变形后意图与尖刺甲壳。

`encounter_coverage` 对有专属状态机的两种敌人使用各自独立oracle，其余21种继续逐意图及循环回归；18遭遇与地图覆盖仍运行。旧遭遇审查的固定Boss循环与压力表为历史结果，不代表本候选。

完整离线检查与最终集成基线记录在Backlog notes；即使全部本地测试通过，原版构建/完整队列复验、17层完整通关与平台验收仍须另行完成。
