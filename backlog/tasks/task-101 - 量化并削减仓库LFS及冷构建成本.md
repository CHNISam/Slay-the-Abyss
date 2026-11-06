---
id: TASK-101
title: 量化并削减仓库LFS及冷构建成本
status: In Progress
assignee:
  - Furinya
created_date: 2026-11-06 01:46
updated_date: '2026-11-06T02:15:00Z'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-SCOPE-GAP-20261105.md
priority: medium
type: task
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前仓库体积与LFS仅有旧快照，缺少checkout下载及冷构建成本证据；TASK-60处理CI下载故障、TASK-87处理指引，本任务只补全体积与构建成本线。架构及协作优先。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 绑定当前源码统计blob、LFS OID可读性、checkout下载字节及冷暖构建墙钟，区分Git pack与官方包大小
- [ ] #2 同环境前后证明确证重复下载或派生物成本已消除，或以实测说明保留原因；不重写历史、不删合法fixture与不可再生资源
- [ ] #3 跨平台构建、许可和候选输入完整性保持，独立复审及实际合后Full通过；导航缺口复用TASK-87不另建指引系统
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定当前源码与任务来源，复用 Git/LFS 清单统计并分别标记可读、缺失和未验证对象，不下载非必需资源。
2. 在云隔离目录记录无生成物与重复构建的真实耗时、产物摘要和派生字节，保留前后同源配对样本及失败。
3. 仅修复有实测且不与其他任务重叠的成本问题，先负例后实现；否则保留资源并明确原因。
4. 独立复审和相关回归后提交 Draft PR，保持原 Full/合后验收与跨平台未验证边界，不提前勾选AC。
<!-- SECTION:PLAN:END -->
