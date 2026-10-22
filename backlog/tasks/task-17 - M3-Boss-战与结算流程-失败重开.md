---
id: TASK-17
title: M3 Boss 战与结算流程 + 失败重开
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 23:24'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-15
  - TASK-16
  - TASK-12.3
priority: high
ordinal: 3
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第一幕 Boss 战、通关结算界面与失败重开闭环。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Boss 有独立阶段与意图
- [ ] #2 击败 Boss 后正式结算（战绩/用时/卡组成果）
- [ ] #3 失败可重新开始，无残留状态
- [ ] #4 M1/M2关口通过后，同一原数据候选真实完成15层到Boss、正式结算和失败重开，记录战绩/用时/卡组、SHA、存档、日志/录像；不可用夹具降低HP冒充
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR29已有本地Boss节点/胜利页/重开处理器；game_ui测试15层使用低HP夹具，不是原数据完整第一幕通关。独立阶段意图、正式平台结算及完整原数据通关尚未证明，保持未完成。

P0正式结算已接线：结果双按钮、单次ABYSS_WIN/LOSE信号、服务器设置胜败后settleStage；v6图编译/写入通过。候选SHA CE9076F4295A7A9B415E9BB160E3FCFE1B552C72D71BF330F48B8ADB8FC2E752。用户真实第1层战败后点结束并结算，进入平台官方失败页（离开/重新挑战）；截图.artifacts/p0/defeat-result-v6.png、official-defeat-settlement-v6.png。Boss胜利/胜利正式结算及平台重新挑战后的资源重置未测，AC保持未完成。
<!-- SECTION:NOTES:END -->
