---
id: TASK-74.16
title: 拆清角色状态投影与资源行职责
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
- [x] #3 独立复审、精确HEAD完整CI与实际合入提交验证通过，M8与设备验收不代领
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定完整a308旧源及statusView导出别名。2.按来源顺序、玩家筛选、资源与目标行拆分同模块职责，不加查询缓存。3.独立VM比较所有字段/顺序/错误/输入图并拒绝语义变异，全helper绝对CC门禁。4.独立复审与精确HEAD及合后完整CI。

2026-11-05接续已合PR514：核对最终head/base/squash tree、PR/队列/push完整检查与Licenses，本轮独立重验旧新差分、变异和完整分片，按证据关闭最终交付AC；历史schema5产物未取得单独记录，不重做实现、不代验设备。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
statusView60→4，八helper最高13，嵌套resource1。252边界完整旧新图及14变异、元表独立反例通过，既有四类消费者通过；组合工程门禁通过。M8和设备未代验，最终HEAD及合后Full待。

13ff Quick真实ENOBUFS，新增原默认raw入口红例。修复只按显式模式打印252完整轨迹，raw仍252边界及全部输入图断言；原14变异和新raw回归通过，默认预算未改。

2026-11-05已复核PR514最终a245、base a308、实际squash78e4e746及相同tree；PR Full41914042810、merge_group41918738466及push41923895912和对应Licenses成功。本轮独立复审40项/35语义变异及新增scry负例PASS；主控原工程门禁和119项CI合同通过。证据见docs/backlog-details/M7-CLOSEOUT-20261105.md及docs/evidence/m7-closeout-20261105/。本轮新独审不补造合前reviewId或schema5历史收据；M7稳定耗时/Fast样本与设备仍未完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合PR514交付余项完成：精确源码树/完整PR与合后CI及本轮独审通过，保留性能与设备边界；详见M7-CLOSEOUT-20261105。
<!-- SECTION:FINAL_SUMMARY:END -->
