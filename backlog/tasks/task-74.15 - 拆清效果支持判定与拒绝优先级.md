---
id: TASK-74.15
title: 拆清效果支持判定与拒绝优先级
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
ordinal: 152000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Effects私有supported复杂度67，目标图、条件、选择与动作能力判定混合；保持动态查询及既有拒绝和异常顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 支持判定及全部新增职责函数圈复杂度不超过15并受可执行门禁检查
- [x] #2 固定完整旧源与当前实现的判定、动态调用、短路异常和输入不变差分一致，关键变异可拒绝
- [x] #3 独立复审、精确HEAD完整CI与实际合入提交验证通过，剩余热点有记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定完整a308旧源，核对动态CardActions.supports与递归入口。2.同模块拆分目标图、scry预检、逐效果条件与数值职责，保留读取与拒绝优先级。3.独立VM差分和动态/异常变异，全helper绝对CC门禁。4.独立复审与精确HEAD及合后完整CI。

2026-11-05接续已合PR514：核对最终head/base/squash tree、PR/队列/push完整检查与Licenses，本轮独立重验旧新差分、变异和完整分片，按证据关闭最终交付AC；历史schema5产物未取得单独记录，不重做实现、不代验设备。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
私有supported67→14，八helper最高13；动态能力/递归/拒绝优先级旧新差分和13变异通过，独立新增分支拒绝顺序反例通过。组合工程门禁通过；精确最终HEAD与合后Full待，AC3不勾。

13ff Full规划被新增夹具EOF多余空行拒绝，未进入完整回归；仅移除空行并按base到完整候选范围diff --check通过，保留原失败。

27d5 Quick暴露新Effects raw入口没有默认源，先新增回归RED；只在未注入时默认当前Effects路径，显式源仍原样加载，所有3raw及Effects差分/13变异5项通过。原完整trace SHA保持；生产与runner未改。

2026-11-05已复核PR514最终a245、base a308、实际squash78e4e746及相同tree；PR Full41914042810、merge_group41918738466及push41923895912和对应Licenses成功。本轮独立复审40项/35语义变异及新增scry负例PASS；主控原工程门禁和119项CI合同通过。证据见docs/backlog-details/M7-CLOSEOUT-20261105.md及docs/evidence/m7-closeout-20261105/。本轮新独审不补造合前reviewId或schema5历史收据；M7稳定耗时/Fast样本与设备仍未完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合PR514交付余项完成：精确源码树/完整PR与合后CI及本轮独审通过，保留性能与设备边界；详见M7-CLOSEOUT-20261105。
<!-- SECTION:FINAL_SUMMARY:END -->
