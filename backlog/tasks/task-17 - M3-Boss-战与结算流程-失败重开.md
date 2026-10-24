---
id: TASK-17
title: 接通Boss、Boss宝箱和胜败结算
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-24 07:48'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-12
  - TASK-13
  - TASK-14
  - TASK-8
references:
  - docs/backlog-details/TASK-17.md
  - docs/M2-SPRINT-20261024.md
priority: high
ordinal: 3
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
让第一幕正常收尾：击败Boss后开独立的Boss宝箱，再进入胜利结算；失败后可以重新开始。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 正常击败Boss后进入第17层独立Boss宝箱，领取正确奖励，再进入正式胜利结算。
- [ ] #2 战败、击杀和特殊阶段不会重复结算；游戏内重开和重新挑战都没有上局残留。
- [ ] #3 保留开发和测试结果；完整试玩与Boss原版规则分别由对应任务检查。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M2冲刺：从3bd3afa隔离并行。Boss事务代理补齐16层Boss卡牌奖励到独立17层合法Boss遗物选择；UI代理接线及退出重开；资源代理检查合法节点和资源账本。主线程整合、固定SHA构建、独立读回，再以同候选实机验收。不降低数值，不把离线回归当实机通关。

Boss遗物暂限定为Black Blood、Slavers Collar、Sozu三件完整实现，不将受限池称为全原版池；胜利必须在第17层领取或显式跳过后才能触发。Boss16奖励后回图手动进入17，三选一交互读取主题配置。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
核心2a097c0/148ae99已在独立树完成并整合：第17层独立宝箱三选一/跳过、BlackBlood替换/12回血、项圈条件能量、Sozu能量/拒药、普通池排除Boss。定点宝箱8组/效果6组通过；尚无本轮官方导入或实机，不勾平台AC。
<!-- SECTION:NOTES:END -->
