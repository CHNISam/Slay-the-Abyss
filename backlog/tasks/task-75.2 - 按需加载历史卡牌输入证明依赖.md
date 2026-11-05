---
id: TASK-75.2
title: 按需加载历史卡牌输入证明依赖
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
parent_task_id: TASK-75
priority: medium
type: enhancement
ordinal: 154000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
普通Lua测试导入会预读并解析仅三个历史手势夹具使用的大型证明链；移除无关启动成本，保留真实历史入口每次新鲜身份验证和原runner合同。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 普通冷暖导入与非历史夹具不加载历史重证明，公开同步API和原runner预算失败传播保持
- [x] #2 三个历史入口、外部cwd、注入reader、缺失篡改及首次成功后源码漂移均按原合同验证并有真实负例
- [x] #3 同环境前后启动成本及完整覆盖有证据，独立复审、精确HEAD及合后完整CI通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.测量并固定普通导入的历史证明读取开销。2.仅将重证明依赖加载移到原exact fixture/root guard内，保持同步API与call-local reader。3.冷暖轻入口、全部真实历史入口、缺失篡改和关联源漂移回归及前后计时。4.独立复审，完整文件集合与精确HEAD及合后CI。

2026-11-05接续已合PR514：核对最终head/base/squash tree、PR/队列/push完整检查与Licenses，本轮独立重验旧新差分、变异和完整分片，按证据关闭最终交付AC；历史schema5产物未取得单独记录，不重做实现、不代验设备。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
仅在原exact root/三个fixture guard后同步加载重证明；21项唯一原runner/输入合同通过，独立有效gzip篡改和同reader暖调用漂移拒绝。BAAB两次每版本机均值59.733→3.434ms，非托管收益。最终Full与合后待，AC3不勾。

2026-11-05已复核PR514最终a245、base a308、实际squash78e4e746及相同tree；PR Full41914042810、merge_group41918738466及push41923895912和对应Licenses成功。本轮独立复审40项/35语义变异及新增scry负例PASS；主控原工程门禁和119项CI合同通过。证据见docs/backlog-details/M7-CLOSEOUT-20261105.md及docs/evidence/m7-closeout-20261105/。本轮新独审不补造合前reviewId或schema5历史收据；M7稳定耗时/Fast样本与设备仍未完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合PR514交付余项完成：精确源码树/完整PR与合后CI及本轮独审通过，保留性能与设备边界；详见M7-CLOSEOUT-20261105。
<!-- SECTION:FINAL_SUMMARY:END -->
