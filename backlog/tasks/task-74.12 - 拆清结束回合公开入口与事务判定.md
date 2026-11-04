---
id: TASK-74.12
title: 拆清结束回合公开入口与事务判定
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 16:47'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-74.12.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 149000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
私有结束阶段拆分后，公开M.endTurn仍CC34、advancedTurnCleanup CC25。需继续治理拒绝/遗物/保留恢复、事务选择与owner回滚，不能只降低私有入口指标。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 拒绝优先级、遗物暂停/终局、保留恢复、两种直达路径、owner及异常恢复旧新差分和真实变异通过
- [x] #2 公开入口及判定/事务职责全部受CC15，保留原短路读取及返回值数量
- [x] #3 既有结束回合/owner回归、独立复审、精确Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定f26aeb30完整旧源与两种结束阶段，先覆盖公开路由/owner/失败边界。2. 按清理判定、保留恢复、事务执行拆同模块职责，保留原短路顺序、snapshot前后读取及两条直达/末尾fallback；不合并协议。3. 完整状态与返回arity差分、真实错误变异、原owner回归和CC15后独立审查；Full及合后不提前完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
公开入口34→13、判定25→8，七helper最高12；12场景完整图差分及12真实变异、原owner/保留/V4回归通过。严格保留两次动态判定、restore早于resolver读取、两种直达/末尾fallback及返回数量。源码与测试均已冻结；独立最终组合、Full及合后未完成。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
公开结束CC34→13、判定25→8，保持拒绝顺序、两次动态判定、owner与返回数量；精确交付通过。
<!-- SECTION:FINAL_SUMMARY:END -->
