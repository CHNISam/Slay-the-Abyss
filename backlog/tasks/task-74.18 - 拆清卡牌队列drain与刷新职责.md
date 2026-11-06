---
id: TASK-74.18
title: 拆清卡牌队列drain与刷新职责
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 22:58'
updated_date: '2026-11-06 01:47'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CardActions.drain复杂度25，队列循环与终局保留和空手刷新判定混合。保留公开密集队列和动态回调合同，不借重构改变调度或异常清理。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 drain和完整模块全部函数及初始化块复杂度不超过15，移除原25例外并以当前完整测量硬门禁约束
- [x] #2 完整固定旧源与新实现独立VM差分覆盖队列身份次序、动态派发、暂停重入、终局刷新、异常部分写入、零返回和随机；真实语义变异拒绝，旧政策证明强度保持
- [x] #3 独立深审、精确HEAD和实际合入提交完整CI及原交付验证器通过，性能未经实测不推断收益
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.认证78e4完整CardActions旧源与旧政策证明。2.仅同模块提取弹出动作保留/执行与空手刷新职责，保留动态读取、公开数组和原异常部分写入。3.完整旧新独立VM与控制面真实变异，原25例外改全模块CC15并接完整测量。4.独立深审与精确候选及实际合后Full。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
drain25→15，两helper8/4，完整模块CC15。75场景含72受控/3完整目录，374回调全图差分逐字一致，18真变异；20专项及5直接Lua通过。独审8旧新边界、真变异及元表/键/别名观察器负例通过；精确CI及合后待，AC3不勾。

2026-11-06复核：PR520实际dedb9ed5与受审PR516的drain源码相同，三事件Full与原merged_passed回执通过，见M7-DELIVERY-20261106；不推断运行性能收益。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
drain及两职责helper已交付并受CC15门禁；75旧新场景/374回调、18真实变异、独立深审及PR520三事件Full与原合后验证通过。
<!-- SECTION:FINAL_SUMMARY:END -->
