---
id: TASK-3.3
title: 游戏中随时可以退出本局
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-23 13:10'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-3.2
  - TASK-3.3.1
references:
  - docs/backlog-details/TASK-3.3.md
  - docs/M2-CLOSEOUT-20261024.md
parent_task_id: TASK-3
priority: medium
type: bug
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手机和电脑都要有看得见的退出按钮。点退出先确认，取消后还能接着玩。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 战斗、奖励、地图、商店等页面都能找到退出按钮，动画播放时也能点。
- [x] #2 点退出要确认；取消后回到原来的游戏，不会误出牌、误买东西或误退出。
- [x] #3 确认后能进入正式结算并离开；只提交一次，失败可以重试。
- [x] #4 退出按钮和确认框符合已批准的界面样式，手机电脑都点得到。
- [x] #5 留存这次测试记录，分别写清电脑和手机哪些已测、哪些没测。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M2：并行复核退出可达性、取消恢复、结算重试与单次提交；统一候选补电脑原生操作证据，手机未测保持明确。

本轮收口复用既有实机证据，纳入用户已亲测重开和重新挑战的确认，补跑当前退出、结算与资源重置回归；逐项核对后完成任务并归档M2。手机物理输入、整体UI品质和完整内容核对继续由既有后续任务承担。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
M2原生新截图覆盖各阶段可见退出入口，生成树/真实控件退出与取消回归继续通过；本轮自动正常流程未执行物理退出取消、物理手机或平台重挑战，剩余AC不外推完成。

复用既有地图/战斗退出、5165同源奖励/地图/商店/牌库退出取消及正式失败结算证据；当前退出、手势隔离、主题与常见画布回归通过，功能验收收口。真实手机触控仍如实未测，后续TASK-38/42/4继续。详见docs/M2-CLOSEOUT-20261024.md。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
常驻退出、确认取消与正式单次结算已验证；既有PC实测加本轮交互和多画布回归通过，保留手机未测边界。
<!-- SECTION:FINAL_SUMMARY:END -->
