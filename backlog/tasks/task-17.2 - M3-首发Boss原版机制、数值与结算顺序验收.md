---
id: TASK-17.2
title: 把Boss的数值和各阶段招式做对
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-27 15:04'
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
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-17
priority: medium
type: task
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按原版核对首发Boss的血量、出招概率、阶段切换和特殊机制。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 血量、伤害、出招概率、阶段切换、变形和死亡顺序都有原版依据，并且实际做对。
- [x] #2 逐项记录依据和差异，没查清的内容不能当成已通过。
- [x] #3 各阶段、随机边界、被打断、反伤和同时死亡等情况都测过，也有实玩记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复核已合并Guardian阶段与开场随机切片及固定来源，逐项标明已知与未知。2. 针对有原版依据的阈值、变形与反伤边界新增独立红测，仅修复证实差异。3. 运行Boss定向与相关战斗回归，记录来源hash及本地证据；保留平台与实玩验收未完成。

2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 离线Boss切片：复读固定319009d5镜像与死亡屏调用链，发现Twin Slam致死后仍执行Sharp Hide移除及Mode Shift重置。独立红测1过4败，最小Boss专属入口修复后5组全过；6份既有fixture共124组回归通过（总129）。来源blob/hash、逐项审计及证据边界见docs/reviews/TASK-17.2-guardian-death-tail.md。未运行平台、导入或实玩，三项AC保持未勾选；全量检查由集成统一运行，syntax脚本在本沙箱spawnSync EPERM未完成。

2026-10-26全面复核：Guardian24组AI、14开场随机、易伤阶段、死亡尾部5组本轮通过；既有M2正常Boss胜败及75卡098正常17层记录保留，未把夹具当自然玩法。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Guardian24组AI、14开场随机、易伤阶段、死亡尾部5组本轮通过；既有M2正常Boss胜败及75卡098正常17层记录保留，未把夹具当自然玩法。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
