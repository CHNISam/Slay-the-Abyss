---
id: TASK-15.15
title: 实现大型酸液敌人的半血分裂
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 06:32'
updated_date: '2026-10-24 06:33'
labels: []
milestone: m-4
dependencies:
  - TASK-15.14
  - TASK-15.7
  - TASK-15.13
references:
  - docs/reviews/TASK-15.14-acid-slime-l.md
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有大型酸液敌人只有基础三招，受到半血伤害后不会分裂，玩家无法体验完整的这个遭遇。复用已有尖刺分裂框架，但按酸液敌人的原版顺序处理。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 半血后切换分裂意图，行动时按剩余生命生成两个独立中型酸液敌人；致死时不分裂。
- [ ] #2 子体本轮不行动，旧队友、死亡队列、随机消耗、奖励和失败回滚保持正确。
- [ ] #3 界面显示真实子体名称，不改变玩家数值，不影响已有尖刺分裂和酸液基础招式。
- [ ] #4 真实失败用例修复、相关回归、独立审查与当前提交CI通过；不冒称平台试玩或完整随机规则一致。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复核固定原版来源和现有合同；补失败回归；只扩已有分裂接线与子体名称；独立审查后提交正常PR并核合后CI。
<!-- SECTION:PLAN:END -->
