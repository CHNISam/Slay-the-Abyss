---
id: TASK-75.3
title: 限制POSIX矩阵并发以减少完整检查排队
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 22:58'
updated_date: '2026-11-04 22:59'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-75
priority: medium
type: enhancement
ordinal: 157000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
真实原生队列Full为33分05秒，实际develop推送30分03秒；13Windows与9POSIX同时竞争执行位置。六组已记录向量支持保留所有分片并限制POSIX同时6项的候选，模型不替代当前托管观测。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 保留13Windows与9POSIX的全部27作业、文件覆盖、原预算权重安全边界权限及交付协议，仅限制POSIX矩阵最多同时6项
- [ ] #2 历史工作流仅逆投影精确批准的并发设置，原完整SHA与合同不刷新；错误值、位置、重复与其他门禁漂移仍拒绝
- [ ] #3 独立复审、精确候选来源和原生队列及实际推送Full通过，记录真实总时长排队与runner成本及目标差距，原交付验证器合后通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定六组真实Full向量、cap6探索与Fast自然样本未知边界。2.只增加POSIX strategy max-parallel=6，保留13/9矩阵及全部原门禁。3.在原历史投影公共入口增加精确唯一批准逆投影，错误值位置重复与无关漂移负例。4.独立复审、真实新候选来源/原生队列/实际推送Full，原交付验证器及真实时长对比。
<!-- SECTION:PLAN:END -->
