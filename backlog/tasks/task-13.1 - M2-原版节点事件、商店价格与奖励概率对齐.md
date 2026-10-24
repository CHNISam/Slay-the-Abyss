---
id: TASK-13.1
title: 核对事件、商店价格和奖励规则
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-24 16:55'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
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
parent_task_id: TASK-13
priority: high
type: enhancement
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
把首发里会出现的事件、商店和奖励按原版逐项检查，修掉固定价格或错误概率等问题。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每项规则都有原版依据，未查清的地方明确列出。
- [ ] #2 事件选项、未知房间变化、营地回血和升级、宝箱产出与原版一致。
- [ ] #3 商店卖什么、价格变化、打折和删牌涨价都按原版。
- [ ] #4 金币、卡牌、药水和遗物的掉落、稀有度与领取顺序都按原版。
- [ ] #5 测试价格和概率的极端情况，不能重复领奖，操作失败时不能丢资源。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 商店专项：在 feat/shop-parity 隔离工作树复用既有价格证据与 Lua 算术；按固定来源核对库存/稀有度，先红后绿覆盖 7 牌/3 遗物/3 药水与一次删除、价格、折扣、事务和重入；移除正常商店分页，保留选牌器分页与触摸归属保护。缺少内容保留明确不可售槽位，不重分概率；记录受限池、原版种子轨迹与实机证据差距；独立 PR 交付，整体 AC 不因 CI 勾选。

2026-10-25 战后金币最小切片：先固定AbstractRoom等原版来源，确认普通与精英的treasure流闭区间、Boss按层misc流、全逃跑与修饰结算；独立向量及真实红例后替换正式入口固定15/30/100，显式领取与重复拒绝保持。只改Run和必要局部模块；失败原子、同局续流和legacy边界逐项验证。宝箱共享全轨迹仍未接，明确保留，不扩卡牌或新遗物，整体AC不勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮领取商店专项，不改事件与奖励算法，不覆盖根工作区 UI 改动；远端基线 b3c2ecb，无其他商店 open PR。

商店专项已实现固定7牌/3遗物/3药水槽、一次删牌、浮动价格、特价与三遗物交互；缺失无色/稀有内容保留不可售槽，无重分概率。新增故障注入先红后绿：补货失败在付款/发牌前整体拒绝。固定seed、阈值穷举、三类补货、价格差分9组、NodeUI31、手势20、旧触点6、退出遮罩5、节点21、事务11/162拒绝与恢复5组定向通过；当前最终全量check仍在执行。离线图已检查；中间副本静态0error/16warning，最终同源副本需重建审计，未官方导入/实机。来源冲突、受限池与共享奖励RNG/全局遗物队列缺口和实机执行单见docs/SHOP_PARITY.md，整体AC保持未勾。

PR163商店切片：已整合最新develop为988aa22。完整npm run check exit0（JS927pass/118条件skip、133份Lua全过、Python17项含1skip）；后续仅增遗物/药水binary32端点测试并通过，普通药水上界52。独立候选33f0b982…同源审计42模块/1997控件/max52/22节点结算，静态0error14warning；根.artifacts/shop-parity-988aa22保留原始证据。用户确认游戏独占后显式clientScriptLog=true尝试run16a0b150，在导入前无法前台失败，无截图/日志/ready；备用窗口管道重试重置均不可用，已请求用户恢复前台/同权限。verify:ui实际FAIL，整体原版与平台AC不勾。当前head Quality首次checkout网络重置，已重跑，最终状态看PR当前SHA。详见docs/SHOP_PARITY.md及docs/evidence/shop-988aa22.json。

M2组合复用PR163；其快递员同名卡错槽问题已由4bf1786改为精确buyCardSlot及过期报价身份校验，当前SHA两Quality成功。精英战后尚无遗物奖励保留本任务缺口。
<!-- SECTION:NOTES:END -->
