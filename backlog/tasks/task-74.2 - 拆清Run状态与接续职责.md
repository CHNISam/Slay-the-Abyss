---
id: TASK-74.2
title: 拆清Run状态与接续职责
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-28 15:25'
updated_date: '2026-10-28 15:38'
labels: []
dependencies: []
parent_task_id: TASK-74
ordinal: 124000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
拆清Run职责并保持状态与接续行为。技术方案和证据见 docs/backlog-details/run-governance.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Run主模块不超过1000行，全部受影响函数及helper复杂度不超过15
- [ ] #2 API、同局状态、房间进入、领奖、跨幕接续、失败回滚与结算保持一致，定向回归通过
- [ ] #3 独立工作树与PR，不修改Nodes、Combat、UI和CI
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
记录基线API与Luacheck复杂度；按初始化、房间接续、奖励、玩家动作拆分并治理热点；行为与API对照回归；总控统一注册与强化门禁；独立PR交总控。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮基线1f260a71，独立A工作树feat/govern-run；原1312行/max57。总控已把全主模块和本轮helper纳入15预算、1000物理行边界及正负例，73条原静态告警无新增。原四项关键变异全部由原断言拒绝；并发重例曾超时，独占按原30秒两幕接续7组通过（22.223秒），保留超时记录。53个API合同与9检查点全图/别名/RNG差分已过；最终PR和组合验证仍待，不作整体完成。
<!-- SECTION:NOTES:END -->
