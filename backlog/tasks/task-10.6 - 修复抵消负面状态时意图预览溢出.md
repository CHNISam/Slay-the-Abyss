---
id: TASK-10.6
title: 修复负面状态被抵消时的意图显示报错
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 02:42'
updated_date: '2026-10-24 03:24'
labels: []
milestone: m-2
dependencies:
  - TASK-10.5
references:
  - docs/backlog-details/TASK-10.6.md
parent_task_id: TASK-10
priority: medium
type: bug
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
状态层数极大、又能抵消负面效果时，敌人意图预览会报错。修好显示，不改变实际战斗结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 能被抵消的负面状态，即使层数很大，也不会让意图预览报错。
- [ ] #2 显示按实际战斗规则处理，不能改本局结果，也不能把真正非法的数值错误藏起来。
- [ ] #3 正常意图、状态详情和卡牌预览仍正常；先复现问题，再确认修好。
- [ ] #4 相关检查和审查通过，不改战斗数值、已批准布局或其他任务的状态。
<!-- AC:END -->
