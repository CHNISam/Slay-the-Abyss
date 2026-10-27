---
id: TASK-10.1.2
title: 验证多张卡牌和长文字是否撑得住
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-22 21:55'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-28'
labels:
  - art validation
  - queued-after-M3
milestone: m-5
dependencies:
  - TASK-10.1.1
references:
  - docs/art/CARD_PRODUCTION.md
  - docs/backlog-details/TASK-10.1.2.md
  - docs/DELIVERY-CLOSEOUT.md
parent_task_id: TASK-10.1
priority: medium
type: spike
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
单张卡牌已能显示和点击，再检查1张、5张、10张同屏与长说明，确认看得清、点得动、不明显卡顿。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 已准备同一场景下的1张、5张、10张卡和长文字样本，并记录界面占用。
- [ ] #2 在游戏里测显示、点击、流畅度和反复进出，没测过的格子留空。
- [x] #3 样本和复现步骤可查，不重做战斗系统；手机、主机留待单独实测。
- [ ] #4 容量结论覆盖TASK-25实际装配资产及动态内容、选中拖放、清理和整屏成本；旧15控件探针不能批准343控件卡面或939控件肖像。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
使用PR208的41档同副本样板比较纯2D、2.5D和原生3D；保持已批准视觉方向，离线/官方导入/PC/手机证据分开。只有新一轮明确键鼠窗口内才做客户端操作；正式装配与完整UI验收仍按原AC逐项完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户2026-10-25明确优先代表性同屏绘制压力与手机路线可行性，不要求精确FPS实验；切换为1435图元组合至高精度蒙版组合的快速逐档筛选，手机未实测不外推。原先基线流程错误与失焦记录保留。
<!-- SECTION:NOTES:END -->
