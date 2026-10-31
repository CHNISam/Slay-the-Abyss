---
id: TASK-13.1
title: 补齐节点经济与完整奖励池的剩余规则
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-31 18:53'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-13
  - TASK-14
references:
  - data/SOURCES.md
  - src/lua/abyss_nodes.lua
  - src/lua/abyss_run.lua
  - docs/backlog-details/TASK-13.1.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/163'
  - docs/DELIVERY-CLOSEOUT.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/reviews/M3-EVENTS-INVENTORY-INTEGRATION.md
  - docs/M3-STATUS-20261028.md
  - docs/reviews/M3-EVENTS-OFFLINE-COMPLETION-20261031.md
  - docs/evidence/m3-completion-20261031/
parent_task_id: TASK-13
priority: medium
type: enhancement
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已合并商店浮动价格/折扣/删牌、独立奖励列表、原版金币与洗牌，以及PR206永久库存/事件事务和独立奖励owner修复。待做的是完整无色/遗物/药水来源池、25事件和全部随机消费链及概率验收；不重复开发已交付价格、领奖和事务。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 已有价格、奖励、事件与道具来源账本，未核实和未实现项有明确记录。
- [x] #2 已合入商店浮动报价、折扣和删牌涨价、独立领奖、原版战后金币及永久库存事务，既有回归通过。
- [x] #3 已实现交易/奖励覆盖边界、重复领取与失败原子性，并保留PR193/206实际验证记录。
- [ ] #4 补齐冻结比赛清单内不依赖持久Save的事件选项、未知房变化和营地/宝箱产出规则，逐项保持原版；跨局留卡与历史资格移未来，不改变保留内容的原池顺序、概率及同局事务。
- [ ] #5 接齐完整商店卡牌、遗物、药水货架及所有价格/折扣/删牌交互，不把已实现报价算法当完整货架通过。
- [ ] #6 接齐金币、卡牌、药水和遗物完整掉落池、稀有度、领取顺序和随机消费，保持原版概率。
- [ ] #7 全池接齐后复验价格/概率极端情况、重复领取及失败资源不丢失，并完成严格平台验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 商店专项：在 feat/shop-parity 隔离工作树复用既有价格证据与 Lua 算术；按固定来源核对库存/稀有度，先红后绿覆盖 7 牌/3 遗物/3 药水与一次删除、价格、折扣、事务和重入；移除正常商店分页，保留选牌器分页与触摸归属保护。缺少内容保留明确不可售槽位，不重分概率；记录受限池、原版种子轨迹与实机证据差距；独立 PR 交付，整体 AC 不因 CI 勾选。

2026-10-25 战后金币最小切片：先固定AbstractRoom等原版来源，确认普通与精英的treasure流闭区间、Boss按层misc流、全逃跑与修饰结算；独立向量及真实红例后替换正式入口固定15/30/100，显式领取与重复拒绝保持。只改Run和必要局部模块；失败原子、同局续流和legacy边界逐项验证。宝箱共享全轨迹仍未接，明确保留，不扩卡牌或新遗物，整体AC不勾。

2026-10-26本轮M3并行：colorless独立工作树补完整无色牌及合法SPECIAL生成依赖，配合inventory接真实药水生成/商店；保留固定源序与稀有度，子集不可冒充完整货架。父线程统一集成。

本轮完整职业来源池已接后，商店须按固定typed来源ID选择并保留未实现身份，不按Capability删池；父线程补正常/补货/失败原子性红绿，既有价格与浮点公式保持。

2026-10-27并发复核：treasure独立树对固定Small/Medium/LargeChest、AbstractChest、TreasureRoomBoss实现箱型/共同roll/金币/共享遗物队列/钩子，主session接正常Nodes与蓝钥匙互斥。缺定义不缩池不重抽，严格入口与回滚定向验证。

2026-10-31 M3整批收口：逐域复核完整两幕源池、经济入口和随机消费；全选项与严格平台按缺口单补验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮领取商店专项，不改事件与奖励算法，不覆盖根工作区 UI 改动；远端基线 b3c2ecb，无其他商店 open PR。

商店专项已实现固定7牌/3遗物/3药水槽、一次删牌、浮动价格、特价与三遗物交互；缺失无色/稀有内容保留不可售槽，无重分概率。新增故障注入先红后绿：补货失败在付款/发牌前整体拒绝。固定seed、阈值穷举、三类补货、价格差分9组、NodeUI31、手势20、旧触点6、退出遮罩5、节点21、事务11/162拒绝与恢复5组定向通过；当前最终全量check仍在执行。离线图已检查；中间副本静态0error/16warning，最终同源副本需重建审计，未官方导入/实机。来源冲突、受限池与共享奖励RNG/全局遗物队列缺口和实机执行单见docs/SHOP_PARITY.md，整体AC保持未勾。

PR163商店切片：已整合最新develop为988aa22。完整npm run check exit0（JS927pass/118条件skip、133份Lua全过、Python17项含1skip）；后续仅增遗物/药水binary32端点测试并通过，普通药水上界52。独立候选33f0b982…同源审计42模块/1997控件/max52/22节点结算，静态0error14warning；根.artifacts/shop-parity-988aa22保留原始证据。用户确认游戏独占后显式clientScriptLog=true尝试run16a0b150，在导入前无法前台失败，无截图/日志/ready；备用窗口管道重试重置均不可用，已请求用户恢复前台/同权限。verify:ui实际FAIL，整体原版与平台AC不勾。当前head Quality首次checkout网络重置，已重跑，最终状态看PR当前SHA。详见docs/SHOP_PARITY.md及docs/evidence/shop-988aa22.json。

M2组合复用PR163；其快递员同名卡错槽问题已由4bf1786改为精确buyCardSlot及过期报价身份校验，当前SHA两Quality成功。精英战后尚无遗物奖励保留本任务缺口。

2026-10-25 集成完成：PR193冻结头e443dbc的完整Quality run40126575413（check/presentation均SUCCESS）已squash合入develop，提交9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db。完整原池生产效果、25事件和组合实机/UI门禁仍未完成，不勾选这些AC。e443候选57模块/UI/完整结算图独立读回通过，但合并期间base新增药水输入归属，正从9ae重建；旧候选不能冒充当前。https://github.com/CHNISam/Slay-the-Abyss/pull/193

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26逐项AC校准：将混合的已实现/已有自动回归与完整池/平台待验拆成独立条款；依据既有合并及验证记录勾选，不新增通过结论。原验收快照保留docs/evidence/backlog-ac-before-20261026.json，全部原范围要求由拆分后条款继续承接。

本轮商店改从完整typed源池选择，缺定义保留同一身份且unavailable，不按能力删池。独立8角色删除定义故障夹具证明其余身份、源ID、价格与RNG不漂移；复审修复Watcher Rushdown/Adaptation来源字段。旧局部价格公式保留，完整遗物/所有概率与平台仍缺。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。
原AC4（仅保留历史要求，不再作为当前比赛必做）：补齐全部25事件选项、未知房变化及完整营地/宝箱产出规则，逐项保持原版。

2026-10-31 M3最终事实核对：本轮事件55幕别路径/42身份全源池公开完成、完整typed商店身份与缺定义不漂移、价格77项及33药水两渠道/连续流通过。#4仍须逐事件全部合法选项/未知房/营地宝箱原版结果矩阵收齐；#5完整货架各类型及全部折扣删牌交互的逐项合证仍需统一；#6完整金币/卡牌/药水/遗物稀有度领取顺序与全部流组合仍需统一；#7严格同候选平台极端价格/重复/失败验收未做。现有专项不是未实现证明，也不外推全域通过。

2026-10-31 补Designer真实Nodes公开服务全分支、空组/瓶装/受保护/不足金币/重复/晚onObtain失败原子回滚；新标准1/1、相关9/9通过，两真实费用/可行性变异被拒。见docs/reviews/M3-EVENT-OPTIONS-AUDIT-20261031.md。未发现新生产缺陷；55路由不冒充所有事件全选项/源hook与官方验收，广义未完成AC保留。

2026-10-31 正常source c3d seed17记录LivingWall初始forget过早传UID的取证脚本错误；ca838只按public picker/choose_card阶段修，真实双步成功后正常战败16层，7新边界与原3事件case通过。玩家生产节点本来正确拒非法初始UID；未改事件池/算法，见m3-mechanism-closeout分源cohort与driver独审。
<!-- SECTION:NOTES:END -->
