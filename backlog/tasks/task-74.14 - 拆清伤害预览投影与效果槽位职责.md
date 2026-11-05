---
id: TASK-74.14
title: 拆清伤害预览投影与效果槽位职责
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 20:41'
updated_date: '2026-11-05 00:48'
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
- [x] #3 独立复审、精确HEAD完整CI与实际合入提交验证通过，剩余热点和设备边界有记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定完整a308旧源和现有入口合同。2.以同模块效果族及槽位职责拆分，保留捕获、稀疏槽、短路和V4克隆语义。3.独立VM旧新差分、边界与变异、全helper绝对CC门禁。4.独立复审与精确HEAD及合后完整CI。

2026-11-05接续已合PR514：核对最终head/base/squash tree、PR/队列/push完整检查与Licenses，本轮独立重验旧新差分、变异和完整分片，按证据关闭最终交付AC；历史schema5产物未取得单独记录，不重做实现、不代验设备。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
预览编排48→6，其余静态职责最高13，避免每查询闭包；完整旧新图/RNG及8真变异通过，组合24项与工程门禁通过。独审新增重入捕获反例通过。精确最终HEAD Full及合后验证待，AC3不勾。

13ff的raw入口复现ENOBUFS；仅按显式差分模式输出164条完整轨迹，默认raw保留全部断言和摘要，不改runner上限。新增raw红绿及轨迹条数门禁、去opt-in真负例通过；原8变异与完整trace SHA保持。

2026-11-05已复核PR514最终a245、base a308、实际squash78e4e746及相同tree；PR Full41914042810、merge_group41918738466及push41923895912和对应Licenses成功。本轮独立复审40项/35语义变异及新增scry负例PASS；主控原工程门禁和119项CI合同通过。证据见docs/backlog-details/M7-CLOSEOUT-20261105.md及docs/evidence/m7-closeout-20261105/。本轮新独审不补造合前reviewId或schema5历史收据；M7稳定耗时/Fast样本与设备仍未完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合PR514交付余项完成：精确源码树/完整PR与合后CI及本轮独审通过，保留性能与设备边界；详见M7-CLOSEOUT-20261105。
<!-- SECTION:FINAL_SUMMARY:END -->
