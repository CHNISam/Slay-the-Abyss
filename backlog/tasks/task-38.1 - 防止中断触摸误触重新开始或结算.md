---
id: TASK-38.1
title: 取消退出后，不要误重开或误结算
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 15:55'
updated_date: '2026-10-26 12:52'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
references:
  - src/lua/abyss_game_ui.lua
  - docs/backlog-details/TASK-38.1.md
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-38
priority: high
type: bug
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
修复旧触摸留在界面上的问题，避免取消退出后又意外点到重新开始或提交结算。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 开关弹窗、换页面、重开或缩放后，之前的触摸不会误重开或误提交结算。
- [x] #2 别的触点和重复点击不会乱执行；正常的新点击仍然可用。
- [x] #3 先复现再确认修好，结算只发生一次；自动检查和游戏实测分别记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26全面复核：本轮game_ui_result_gestures20/20，旧手势/重复/新点击和单次结算通过；PR122修复已合，最终整合PR213全绿；本地和实际平台边界分开记录。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
本轮game_ui_result_gestures20/20，旧手势/重复/新点击和单次结算通过；PR122修复已合，最终整合PR213全绿；本地和实际平台边界分开记录。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
