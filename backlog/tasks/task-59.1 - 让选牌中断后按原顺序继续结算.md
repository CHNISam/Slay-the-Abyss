---
id: TASK-59.1
title: 让选牌中断后按原顺序继续结算
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-27 04:15'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0
  - docs/BACKLOG-RECONCILE-20261026.md
parent_task_id: TASK-59
priority: medium
type: feature
ordinal: 96000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有最终弃牌动作不足以承接占卜等牌中途选牌。统一可暂停结算，避免把后续抽牌、使用牌处置和能力收益提前执行；保留当前选择阶段失败恢复和跨战斗过期拒绝。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 能在牌的中间动作等待玩家选择，恢复时不重放此前已完成的伤害或格挡。
- [x] #2 使用牌处置、原生剩余效果、能力追加动作及队头动作保持固定来源顺序。
- [x] #3 选牌状态可保存为数据；重复、过期、跨战斗和无效选择不能执行，失败恢复当前阶段状态。
- [x] #4 保留末敌死亡与玩家死亡的不同取消规则，已有格挡等保留动作不被误删。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮收口：按原验收逐项对照已合入机制，在e3a9fe2c复跑对应现有回归；关闭本地机制切片，完整卡池与平台自然玩法留父任务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26实际复验：watcher_scry 18组通过，覆盖真实中途选择、纯数据恢复、不重放前段、过期拒绝和玩家/末敌不同死亡顺序。详见docs/BACKLOG-RECONCILE-20261026.md；本轮无游戏输入、导入或完整check。完整卡池及自然平台验收留父任务。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合入的本地机制切片完成；e3a9fe2c现有回归复验：watcher_scry 18组通过，覆盖真实中途选择、纯数据恢复、不重放前段、过期拒绝和玩家/末敌不同死亡顺序。原验收四项齐备，父任务的正式入口、全池与平台实机仍保留。
<!-- SECTION:FINAL_SUMMARY:END -->
