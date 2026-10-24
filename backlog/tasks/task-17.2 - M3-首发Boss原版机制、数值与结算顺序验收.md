---
id: TASK-17.2
title: 把Boss的数值和各阶段招式做对
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-24 10:15'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-8
  - TASK-11
references:
  - docs/backlog-details/TASK-17.2.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/reviews/TASK-17.2-guardian-death-tail.md
parent_task_id: TASK-17
priority: high
type: task
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按原版核对首发Boss的血量、出招概率、阶段切换和特殊机制。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 血量、伤害、出招概率、阶段切换、变形和死亡顺序都有原版依据，并且实际做对。
- [ ] #2 逐项记录依据和差异，没查清的内容不能当成已通过。
- [ ] #3 各阶段、随机边界、被打断、反伤和同时死亡等情况都测过，也有实玩记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复核已合并Guardian阶段与开场随机切片及固定来源，逐项标明已知与未知。2. 针对有原版依据的阈值、变形与反伤边界新增独立红测，仅修复证实差异。3. 运行Boss定向与相关战斗回归，记录来源hash及本地证据；保留平台与实玩验收未完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 离线Boss切片：复读固定319009d5镜像与死亡屏调用链，发现Twin Slam致死后仍执行Sharp Hide移除及Mode Shift重置。独立红测1过4败，最小Boss专属入口修复后5组全过；6份既有fixture共124组回归通过（总129）。来源blob/hash、逐项审计及证据边界见docs/reviews/TASK-17.2-guardian-death-tail.md。未运行平台、导入或实玩，三项AC保持未勾选；全量检查由集成统一运行，syntax脚本在本沙箱spawnSync EPERM未完成。
<!-- SECTION:NOTES:END -->
