---
id: TASK-59.1
title: 让选牌中断后按原顺序继续结算
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-25 08:18'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0
parent_task_id: TASK-59
priority: high
type: feature
ordinal: 96000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有最终弃牌动作不足以承接占卜等牌中途选牌。统一可暂停结算，避免把后续抽牌、使用牌处置和能力收益提前执行；保留当前选择阶段失败恢复和跨战斗过期拒绝。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 能在牌的中间动作等待玩家选择，恢复时不重放此前已完成的伤害或格挡。
- [ ] #2 使用牌处置、原生剩余效果、能力追加动作及队头动作保持固定来源顺序。
- [ ] #3 选牌状态可保存为数据；重复、过期、跨战斗和无效选择不能执行，失败恢复当前阶段状态。
- [ ] #4 保留末敌死亡与玩家死亡的不同取消规则，已有格挡等保留动作不被误删。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
下一阶段用数据化动作队列暂停含占卜的出牌路径，保留既有路径；原生剩余效果、UseCard处置、追加能力动作分开，选择恢复采用当前阶段原引用事务。全量验证中的sts-integration保持冻结。
<!-- SECTION:PLAN:END -->
