---
id: TASK-16.1
title: 把伤害、抽牌和结算顺序算对
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-25 01:56'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-8
  - TASK-11
references:
  - src/lua/abyss_combat.lua
  - data/SOURCES.md
  - docs/backlog-details/TASK-16.1.md
parent_task_id: TASK-16
priority: high
type: enhancement
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对所有卡牌和敌人共用的基础规则，避免同一种效果在不同地方算出不同结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每条计算规则有原版依据，未知和差异明确记录。
- [ ] #2 伤害、格挡、状态加减、多段、反伤、中毒和死亡处理的数值与先后顺序正确。
- [ ] #3 抽牌、洗牌、弃牌、消耗、满手、费用支付和随机选择符合原版。
- [ ] #4 用原版预期结果检查特殊情况；卡牌、敌人和道具用同一套正确规则。
- [ ] #5 保存测试与实际游戏记录，明确各部分验证到了哪一步。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-25 正式洗牌独立片：先固定CardGroup与DrawCardAction来源，验证masterDeck初始顺序、尾端抽牌、每次含空/单牌shuffle消费一次randomLong并播种Java48/Collections。正式state.shuffleRng按层独立，初始/弃牌重洗及过量请求空堆均按源顺序；先独立向量和真实红例，再接线并覆盖出牌失败回滚/恢复，legacy显式入口保留但不作原版认证。只改Combat与局部fixture，不扩奖励/其它流，整体AC不勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25 PR193已合入9ae1aec，check/presentation完整通过。新卡牌状态切片建立唯一run.cardRng+offset owner，Shop准备与购买成功后才提交，不再持久shopRng.card；8组状态/入口、商店15组、致死药水4组及独立oracle 228原语/148稀有度偏移全部通过。完整卡牌身份/奖励概率尚未接，不能计整池或平台AC；见docs/reviews/TASK-16.1-card-random-owner.md。

2026-10-25 合并门禁补查：6457b61 的 Quality 40134143690 为 JS1209通过/1超时/119跳过，完整Lua未执行。原生子代理将意图预览原12组逐字拆为4/3/5，原生成UI入口及另外3份夹具共6文件通过，各5783/14048/8177/12415/8684/1922ms，全部保留30秒。Codex将原问号房220种子矩阵分为1–110、111–220，两半均保留所有逐种子断言并各自验证4路由/7事件，18170/16867ms通过；其余13组原文不变，3741ms通过。断言保留证明、实际红绿和只读复审已归档；docs/CI.md补充重复准备成本、可变状态隔离/别名及完整种子拆分要求。卡牌夹具缓存曾因RNG别名复审返工，最终93组20931ms通过；中间超时未改写为通过。子代理总墙钟耗时和实际费用未单独取得，Codex额度节省未知；未使用收费模型回退。本批仍须新当前SHA完整CI成功，父任务/平台验收不关闭。

2026-10-25 当前96d2f39完整Quality40136147836：JS1329总项/1210通过/0失败/119跳过，意图拆分、card_help_release7969ms、card_pool9055ms均实际通过；完整Lua继续到potion_targeting，旧P12仍假定总定义仅7瓶而失败，后续Lua未执行。gh run view日志曾为空或遗漏整个失败步骤，最终直接jobs/120997962312/logs取667708字节原始日志定位，不以汇总缺失推断通过。已将P12改为独立12ID目标表和原7/新增pending5边界，原11组操作断言逐字保留，按5/4/3独立执行，v22.22.1定向15097/6851/3975ms全绿；真实获取轨迹专项3081ms通过。首次本地整文件曾30s超时及准备命令EPERM/未生成夹具失败分别保留，不算当前绿。docs/CI.md已补定义数与可获池区别、完整日志取证和运行时记录；本轮CI实际v24.18.0，与本地v22.22.1不同，未做控制变量A/B，不断言它是时差原因。新当前SHA完整CI仍待通过，不关闭父任务或平台AC。

2026-10-25 4fc3606 Quality40138088333在本机Node22.22.1再次于card_pool原30000ms超时，前92组均已完成，最后奖励矩阵未完成；JS1210通过/0失败。直接原始作业日志与96d2轮对照确认同标签实际有两台runner：本机DESKTOP-UDICC39/Node22.22.1，STA-Sister-Win/DESKTOP-39DJ9M2/Node24.18.0；此前按单机解释耗时不完整，不断言具体性能原因。已将最后真实奖励组独立，共用逐字不变的30卡/7阻止独立oracle，完整93组和128上限/原earlybreak保留；同一失败主机Node22定向92组21126ms、奖励1组6418ms全过。CLI改为逐夹具保留失败并继续检查，最后始终非零；3项真实CLI红→绿和原7诊断均通过，组合10项再核通过，runLua/API/每文件时限/发现范围不变。相应子代理仅测试切片交付，耗时记录在根artifact；费用与额度节省未知。docs/CI.md记录双runner、完整取证和失败聚合；新当前SHA完整CI仍须成功，未关闭父AC。

2026-10-25 0b34ca6 Quality40139999800为JS1211通过/2失败/119跳过，完整Lua未执行：旧发现测试仍要求遇错即停，以及potion_basic_five原11组30000ms超时。前者仅同步旧消费者并强化排序/失败诊断/最终非零，Node22相关11项通过1955ms；后者原11组逐字拆成库存原子2/抽牌5/状态4，真实JS3项一次全过，三片10270/2642/5479ms，原获取专项3756ms，全部沿用30秒。两原生子代理独立树交付，另一个子代理只读复审逐块确认全部断言保留，无确认P1/P2；费用/额度节省未知。已补docs/CI.md契约消费者同步要求及HANDOFF当前分层边界。本批停止扩功能，当前SHA完整CI全绿后及时合入develop；父任务、完整内容池和平台AC不关闭。

2026-10-25 308c1af Quality40141217243被整套20分钟上限取消：JS1332总项/1213通过/0失败/119跳过；完整Lua尝试123/207到louse_ai，gremlin_gang单份30000ms超时，其余尾段未执行。纯测试拆分保留原29组/1680穷举/源与seed向量/三个真实入口四失败/17其它遭遇，按1/18/5/5执行，Node22实际2146/11289/4929/5629ms全过，原数据消费者21项通过；另代理逐块只读复审无确认P1/P2。子代理首次Tee遗漏日志目录未算绿，纠正前置后按原范围完成有效验证，未改生产或时限。单次补查余84先完成50PASS/0FAIL，另一独立CI开始占用本机后停止自有collector，仅run.lua标INTERRUPTED及33NOT_EXECUTED，旧日志/每文件hash保留；root曾把未执行计为非PASS后已更正，未报告为实际断言失败。总job20改45分钟，六阶段与现有check:rules命令及顺序静态相等并维持默认失败阻止后续，单fixture/全部断言不变；独立复审确认门禁语义未减弱。另一runner空闲，立即提交新当前SHA完整CI覆盖全部剩余内容，通过就合并；费用/节省未知，父AC及实机仍不关闭。

2026-10-25随TASK-16完整75张候选推进：共享牌动作队列与独立牌队列、UID选牌、完整消耗/抽牌触发、房间shuffleRng和cardRandomRng、run.cardRng+稀有度偏移已接入并有专项回归。补正同优先级能力按施加顺序触发、Double Tap/Rampage共享身份成长、暂停事务克隆引用，以及Burn/Regret回合末顺序。原始75卡名保留，旧附件允许自定义名称仅为历史口径。仍缺Courier补货MathUtils身份熵接线、正版PC构建身份认证、完整同源回归和逐卡平台联动证据，不将可复现当原版一致性通过。源a891451整合develop7f11cc2，150普通/升级与75获取升级下一战事务通过；平台新组合正在重建，历史启动/普通实战不移算到新组合。

2026-10-25：Courier职业补货身份改走独立MathUtils语义的会话熵，稀有度仍共用cardRng；6组外部熵/失败原子性、15组重复卡槽、既有商店专项通过。依据与精确边界见docs/reviews/TASK-16-warrior75-courier.md。原作全局外部随机历史、PC二进制认证和平台商店实玩仍未验；不勾选严格验收。7854a5e修复完整牌名/效果裁切、重复Searing Blow升级预览，900条菌兽与每色800条虱虫决策断言均保留，构造优化后分别约2.5/3.4秒；完整CI待新SHA。

整合develop9ae1aec时复核AbstractRoom.endTurn发现临时费用边界：原版在回合末只重置手/抽/弃牌堆，排除消耗堆。先新增跨回合零费Bludgeon→Exhume取回红例（错误3费），再把重置移到回合末且排除消耗堆，40组边界通过。正规房间HP/AI/misc/洗牌流、手动金币奖励与完整75卡奖励cardRng已共同接线；combat_gold13、reward_flow10、Boss奖励事务及药水失败原子性专项通过。历史529原生150基础升级/六专项通过但选牌脚本错误、卡名第二行和选择费用未通过；cursorArea及新标题布局需新同源官方Lua门禁后实测。

新增严格复审发现两个复制语义差异，均先红后绿：Anger stat-equivalent副本须保留实例伤害修正和costForTurn；Dual Wield多个候选的选择分支须移除原选择、生成amount+1个新身份副本，并把暂存非候选放回剩余候选之后；单候选快路径保留原身份。修复后warrior75_edges42组、copied_attack34组通过。固定源依据与SHA补sources.json。505原生证据不被后续改动冒用，新运行源须另建构建/导入/实机证据。

补Mega Crit官方PC V2.2公告的独立数值复核：Bloodletting能量2/3、Hemokinesis伤害15/20与自损2、Rupture+费用1与每次力量2，均与当前实现一致；来源docs/evidence/warrior75/official-v2.2.json。正常规则driver首轮seed42在第6层Nob战败（2胜，HP0，牌组12），不计通关；保留失败并调整仅测试策略：读取可见Enrage避免无谓技能，合法路线优先避开起始牌组高风险精英；未改任何产品数值/规则/卡池。

2026-10-25合并前完整Quality40148436803（9a4cf64）：JS1339项1220通过/119跳过/0失败、呈现22通过；完整229 Lua文件记录六份30秒超时及potion_reward_atomic两条过时断言。药水胜利应恰好消费一次持续cardRng，现核对prepareRewards的完整快照与稀有度偏移，原失败回滚和第二次操作不变性保留。六套测试按独立case/seed拆分，50奖励诊断、11动态卡面组含80牌双版本、40节点UI、31坐标边界、128Boss seed、1680菌兽路径全部保留；每文件30秒不变，跨种子聚合改为各批更强全rare覆盖和独立oracle完整笛卡尔覆盖。51个相关文件本地全部通过，最长13786ms；原始/新helper摘要与不重叠覆盖审计及每文件结果见docs/evidence/warrior75/ci-fixture-partitions.json和ci-partitions-local-results.json。语法/Backlog/diff检查通过；提交后的完整CI仍为合并门禁，严格75张和平台父AC仍不关闭。
<!-- SECTION:NOTES:END -->
