---
id: TASK-17
title: M3 Boss 战与结算流程 + 失败重开
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 22:21'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-15
  - TASK-16
  - TASK-12.3
priority: high
ordinal: 17000
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
<!-- SECTION:NOTES:END -->
