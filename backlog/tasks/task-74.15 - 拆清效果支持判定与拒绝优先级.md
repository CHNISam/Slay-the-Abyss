---
id: TASK-74.15
title: 拆清效果支持判定与拒绝优先级
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 20:41'
updated_date: '2026-11-04 20:41'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 152000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Effects私有supported复杂度67，目标图、条件、选择与动作能力判定混合；保持动态查询及既有拒绝和异常顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 支持判定及全部新增职责函数圈复杂度不超过15并受可执行门禁检查
- [ ] #2 固定完整旧源与当前实现的判定、动态调用、短路异常和输入不变差分一致，关键变异可拒绝
- [ ] #3 独立复审、精确HEAD完整CI与实际合入提交验证通过，剩余热点有记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定完整a308旧源，核对动态CardActions.supports与递归入口。2.同模块拆分目标图、scry预检、逐效果条件与数值职责，保留读取与拒绝优先级。3.独立VM差分和动态/异常变异，全helper绝对CC门禁。4.独立复审与精确HEAD及合后完整CI。
<!-- SECTION:PLAN:END -->
