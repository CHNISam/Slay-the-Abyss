---
id: TASK-74.14
title: 拆清伤害预览投影与效果槽位职责
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
ordinal: 151000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前 Combat.previews 圈复杂度48，效果投影与槽位编排混合；仅治理既有语义，不接管M8预览正确性与设备验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 预览编排及全部新增职责函数圈复杂度不超过15并受可执行门禁检查
- [x] #2 固定完整旧源与当前实现在独立VM差分一致，保留目标槽位、错误、输入全图及随机边界，关键变异可拒绝
- [ ] #3 独立复审、精确HEAD完整CI与实际合入提交验证通过，剩余热点和设备边界有记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定完整a308旧源和现有入口合同。2.以同模块效果族及槽位职责拆分，保留捕获、稀疏槽、短路和V4克隆语义。3.独立VM旧新差分、边界与变异、全helper绝对CC门禁。4.独立复审与精确HEAD及合后完整CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
预览编排48→6，其余静态职责最高13，避免每查询闭包；完整旧新图/RNG及8真变异通过，组合24项与工程门禁通过。独审新增重入捕获反例通过。精确最终HEAD Full及合后验证待，AC3不勾。

13ff的raw入口复现ENOBUFS；仅按显式差分模式输出164条完整轨迹，默认raw保留全部断言和摘要，不改runner上限。新增raw红绿及轨迹条数门禁、去opt-in真负例通过；原8变异与完整trace SHA保持。
<!-- SECTION:NOTES:END -->
