---
id: TASK-74.16
title: 拆清角色状态投影与资源行职责
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 20:41'
updated_date: '2026-11-04 21:09'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
documentation:
  - docs/backlog-details/M7-QUERY-BATCH-20261105.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 153000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Actor.statusView复杂度60，将敌人来源顺序、玩家状态筛选和实验资源行混合；仅拆分已有投影，不更改批准UI及玩法。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 状态投影及全部新增职责函数圈复杂度不超过15并受可执行门禁检查
- [x] #2 固定完整旧源与当前实现的顺序、零负状态、字段nil与false、异常及输入图和随机状态差分一致，关键变异可拒绝
- [ ] #3 独立复审、精确HEAD完整CI与实际合入提交验证通过，M8与设备验收不代领
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定完整a308旧源及statusView导出别名。2.按来源顺序、玩家筛选、资源与目标行拆分同模块职责，不加查询缓存。3.独立VM比较所有字段/顺序/错误/输入图并拒绝语义变异，全helper绝对CC门禁。4.独立复审与精确HEAD及合后完整CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
statusView60→4，八helper最高13，嵌套resource1。252边界完整旧新图及14变异、元表独立反例通过，既有四类消费者通过；组合工程门禁通过。M8和设备未代验，最终HEAD及合后Full待。

13ff Quick真实ENOBUFS，新增原默认raw入口红例。修复只按显式模式打印252完整轨迹，raw仍252边界及全部输入图断言；原14变异和新raw回归通过，默认预算未改。
<!-- SECTION:NOTES:END -->
