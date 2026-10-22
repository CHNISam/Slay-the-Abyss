---
id: TASK-22.2
title: Milestone 顺序验收与证据收口
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 22:13'
updated_date: '2026-10-22 22:24'
labels: []
dependencies: []
parent_task_id: TASK-22
type: chore
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
修复任务跨阶段悬挂和多Milestone同时冲刺；证据与顺序关口见docs/MILESTONES.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 M0有真实完成证据并收口；M1保留真实战斗关口
- [x] #2 M2-M5边界有限，未来工作不伪装当前冲刺，依赖无环
- [ ] #3 整改已提交PR并有CI成功证据，原工作区受保护；合并后核对develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对最新develop、全部任务和PR/CI。2. 用CLI拆分代码/平台/发布验收并修复依赖。3. 复跑门禁与doctor，提交PR并在精确head全绿后squash集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已用CLI完成M0收口、跨阶段拆分与依赖调整。完整npmcheck通过：JS124pass6skip/Lua153/Python12pass1skip；doctor仅旧分支TASK24诊断。平台导出实测暴露60子控件限制，M1未关闭。待PR/CI完成AC3。
<!-- SECTION:NOTES:END -->
