---
id: TASK-12.3
title: 实测地图、七类房间和跨房间资源
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 22:21'
updated_date: '2026-10-24 07:48'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-3
  - TASK-12
  - TASK-13
  - TASK-14
references:
  - docs/backlog-details/TASK-12.3.md
  - docs/M2-SPRINT-20261024.md
parent_task_id: TASK-12
priority: high
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
在游戏里正常选路，逐个检查各类房间能不能用，换房间后血量、金币和背包有没有出错。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 能正常开局并沿合法路线前进，七类房间都能进入；地图、16层Boss、17层Boss宝箱位置正确。
- [ ] #2 营地回血和升级、商店买东西和删牌、事件选择、开宝箱、战后领奖都能正常完成。
- [ ] #3 换房间后血量、金币、卡组、遗物和药水保持正确；重开后清空上一局。
- [ ] #4 保存同一个版本的试玩记录；概率检查和完整通关分别由对应任务确认。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24：先审计合法路线、各房间命令与资源继承，补独立账本和必要回归。与Boss17切片统一后构建同源候选，实机记录七类房间、回血升级、交易删牌、事件、奖励与跨节点状态；只按本轮证据验收。

审计发现基线无药水正常获得调用：复用已通过CI的商店PR163，不重复开发；另按固定原版来源接战后药水掉落、领取/跳过及满槽保持，保留独立随机计数。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
并行审计：正常地图seed2719在第14层的event入口会受限七事件池耗尽而拒绝，但同层另有商店可绕行，尚未证明整局卡死；完整事件池归M3。精英战后尚无遗物奖励记入M3规则缺口，不能以本轮M2流程宣称完整原版奖励一致。
<!-- SECTION:NOTES:END -->
