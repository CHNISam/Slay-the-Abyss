---
id: TASK-81.2
title: 避免不可建模改动的无用源码扫描
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 05:36'
updated_date: '2026-11-06 05:36'
labels: []
milestone: m-7
dependencies: []
parent_task_id: TASK-81
priority: medium
type: bug
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
快速反馈在仅docs/HANDOFF等不可建模输入时仍先枚举和读取全部源码，随后才返回Full。已用拒绝语料枚举的真实CLI探针确认这段无用IO；改动范围判定可提前完成，不能因此丢失混合改动的有效反馈。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 仅不可建模输入或空改动的CLI不枚举源码语料，原Full结论、原因和非回归通过提示保持
- [ ] #2 混合已映射与未知输入保留原选集及Full回退，特殊受支持输入和高风险保守边界不变
- [ ] #3 确定性IO反例旧实现失败、修后通过，定向合同与独审通过并按原正常集成门禁交付；不伪称整体CI提速
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先在原quick-feedback测试中以预加载IO守卫证明仅不可建模CLI不应读取语料，观察旧实现失败；复用同一输入路径谓词，在纯不可建模集合时跳过语料加载，混合和可建模输入仍走原图。核对两advisory模式及related plan、空集、特殊fixture输入与原Full政策，独审后集成。
<!-- SECTION:PLAN:END -->
