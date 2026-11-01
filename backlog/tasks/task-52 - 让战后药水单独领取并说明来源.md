---
id: TASK-52
title: 按初代奖励列表领取并独立进入选牌
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 12:45'
updated_date: '2026-10-27 15:04'
labels:
  - required ui rule-parity
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-52.md
  - docs/backlog-details/TASK-52-UI-READABILITY.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: medium
type: bug
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战后先显示金币、药水与卡牌奖励条目；点击卡牌进入独立选牌页，选择或跳过后回列表。严格按固定初代PC来源处理领取、满槽、Sozu与继续，不再增加逐项放弃确认。来源、实现和实机证据见附件。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 选择或跳过卡牌不会领取或吞掉药水；PC跳过只返回列表且可重开。
- [x] #2 金币、失金与药水独立点击领取；药水显示名称、效果和数量，满槽保留条目并说明丢弃旧药水后重试，Sozu点击消耗条目。
- [x] #3 继续可去地图并返回未领奖励；成功换房后才失效，失败进入保留，重复或过期输入不能消费奖励。
- [x] #4 原版交互有固定源码与真实控件树回归；数值随机链、候选导入和本轮实机/UI验收边界明确保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 以固定PC原文核对战利品列表、独立选牌页、Skip和Proceed的页面归属。2. 用真实Run与生成UI复现复杂并行动作和标题叠字，再重做列表与选牌互斥、金币药水分别领取和回看未领奖励。3. 将23状态可读性、旧输入归属、满槽及金币资源账本纳入现有自动检查；新导入前核验官方外部Lua。4. 组合完整检查、构建只读副本和独立读回，官方新导入并收集本轮日志/截图；实机与verify:ui缺口明确保留。

2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地修复选牌/跳卡自动收药；领取、放弃与前往地图独立。固定原版RewardItem/AbstractRoom/AbstractDungeon/PotionHelper已重读，完整同seed拒绝采样链和Sozu差异保留TASK-13.1。新Run3/UI2与既有药水7/UI3/失金10组通过；宿主地图JS12及safe-area布局1项通过，全Lua正在收集。免费委派因自动审批出境授权拒绝未执行，由Codex接管，未收费回退；节省额度未知。未制作或验证新平台候选，保持进行中。

旧领奖夹具迁移收尾：只在有效选牌后显式处理独立药水并离开奖励，保留原规则/数值/原子性/旧触摸断言。上一轮169文件中27个失败fixture已逐项定向修复并取得通过证据（首轮迁移26绿，另1个无失金页纯重绘手势回归已定位并修复）；相邻9个奖励归属/held/released/独立领取fixture全绿，宿主/地图/奖励布局JS13项全绿。未重启169文件全套、未放宽超时；CI与实机仍由集成线程统一验证。详情和日志哈希见TASK-52附件及结构化证据。

补充检查：validate:data与check:syntax均通过；语法检查首次在受限沙箱因Node子进程EPERM退出，以允许子进程的宿主权限运行同命令后通过。无平台导入、实机或verify:ui证据，保持In Progress，交集成线程统一验收。

按用户最新实机反馈重做为原版列表→选牌→列表；Skip只返回，Proceed可先看地图并回看，合法换房成功才失效。普通金币改独立点击到账，Sozu点击消耗、满槽原子拒绝。新增10组Run/生成宿主和独立5项可读性守卫；22项奖励/宿主/布局组合已通过，既有奖励夹具定向迁移正在收尾。发现并修复返回入口跨牌库旧手势及60直属子项上限，未清状态绕断言。无新副本/导入/实机/verify:ui，保持进行中；完整check交集成线程。免费委派路径未重试，Codex实施与审查，费用及额度节省未知。

本片定向收尾：首轮59个相关Lua文件收集的28个失败均已有对应修后通过证据（包含一次并行构建读到半写生成树的宿主重跑）；额外混合宿主与held/released组合通过，独立battle_ui 53组通过。新10组真实奖励生命周期、独立5项可读性守卫及宿主/布局组合22项通过；check:syntax、validate:data、diff --check通过。保留初始失败与逐项修后JSON，未重跑全项目check，未修改超时预算；源码/生成树通过不代表副本/导入/实机或UI总门禁。

生产41320fe已由独立reward_ui_guard最终重跑：5项守卫全绿、23状态，日志SHA256 e2e5d04fda66eeb0bf87d009392febfd88a113a416014a55d07e0308e0369ea3，快照020ec636bb4b8c564bc7ee159680441d7b3612a29766ed77f2f8d8aef8b0208c；来源与各批证据见docs/evidence/reward-flow-parity-20261024.json。没有将源码/机器门禁替作本轮实机，任务状态保持进行中。

2026-10-25 分工交付已组合到c68470f：原版式战利品列表/独立选牌、Skip只回列表、Proceed可回看；奖励页反馈拥有独立区域，23真实渲染状态回归先红后绿；资源审计补显式金币与待领奖励快照。冻结生产e2eefaa副本SHA256=226463ca068f726eab59adb69c497c34781954ca5a8062d2e73193c629854eb8，独立源码/UI/结算图读回通过。首次完整JS1111过/2失败/119跳过：一项Oracle已有CRLF工作区未随eol属性重写，恢复约定LF后原hash断言3/3通过；另一项新返回战利品按钮被旧整页断言误分类，由独立Agent处理。尚未本轮官方导入/实机/verify:ui，保持进行中。

2026-10-25 PR193已合入develop 9ae1aec。准确正常候选473f7018已新导入官方1854，57模块正式sourceguard通过，新41号日志有ready/clock seed25757与首战；没有本轮奖励闭环截图或日志，不据此勾平台AC。第二轮工具因另一实际running试玩f4d29923阻止，未启动/未抢占。证据docs/evidence/m3-core-live-smoke-20261025.json。

2026-10-25 集成完成：PR193冻结头e443dbc的完整Quality run40126575413（check/presentation均SUCCESS）已squash合入develop，提交9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db。完整原池生产效果、25事件和组合实机/UI门禁仍未完成，不勾选这些AC。e443候选57模块/UI/完整结算图独立读回通过，但合并期间base新增药水输入归属，正从9ae重建；旧候选不能冒充当前。https://github.com/CHNISam/Slay-the-Abyss/pull/193

2026-10-26状态整理：PR193奖励列表/独立选牌与PR191药水栏即时刷新已合入，52.2保持Done；本任务不再重复实现这些切片。最终列表交互与本轮同候选自然领奖/UI证据仍待验。

2026-10-26全面复核：PR193列表/独立选牌实现已合，reward_flow_parity本轮10/10；保留满槽、Sozu、独立领取及过期事务原检查；原AC4的随机/平台/UI边界明确由12.5/47及M4承接。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR193列表/独立选牌实现已合，reward_flow_parity本轮10/10；保留满槽、Sozu、独立领取及过期事务原检查；原AC4的随机/平台/UI边界明确由12.5/47及M4承接。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
