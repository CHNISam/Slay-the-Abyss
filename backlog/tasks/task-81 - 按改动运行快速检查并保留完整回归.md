---
id: TASK-81
title: 按改动运行快速检查并保留完整回归
status: In Progress
assignee:
  - Codex
created_date: '2026-10-28 15:30'
labels: []
dependencies: []
priority: medium
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
方案与真实Runner证据见docs/CI-FAST.md。普通PR消除重复回归，保留高风险完整检查。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通PR按影响选测；高风险及develop和发版完整回归
- [ ] #2 保留断言与Required Checks；失败取消缺失均拒绝
- [ ] #3 真实Runner Fast P50≤5分钟、P90≤10分钟；Full≤30分钟
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
采集基准与保护；实现影响计划和稳定汇总；负例与真实Runner验收。
<!-- SECTION:PLAN:END -->
