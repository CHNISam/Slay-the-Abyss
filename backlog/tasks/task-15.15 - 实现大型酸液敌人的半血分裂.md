---
id: TASK-15.15
title: 实现大型酸液敌人的半血分裂
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 06:32'
updated_date: '2026-10-27 04:15'
labels: []
milestone: m-4
dependencies:
  - TASK-15.14
  - TASK-15.7
  - TASK-15.13
references:
  - docs/reviews/TASK-15.14-acid-slime-l.md
  - docs/reviews/TASK-15.15-acid-slime-split.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/164'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有大型酸液敌人只有基础三招，受到半血伤害后不会分裂，玩家无法体验完整的这个遭遇。复用已有尖刺分裂框架，但按酸液敌人的原版顺序处理。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 半血后切换分裂意图，行动时按剩余生命生成两个独立中型酸液敌人；致死时不分裂。
- [x] #2 子体本轮不行动，旧队友、死亡队列、随机消耗、奖励和失败回滚保持正确。
- [x] #3 界面显示真实子体名称，不改变玩家数值，不影响已有尖刺分裂和酸液基础招式。
- [x] #4 真实失败用例修复、相关回归、独立审查与当前提交CI通过；不冒称平台试玩或完整随机规则一致。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复核固定原版来源和现有合同；补失败回归；只扩已有分裂接线与子体名称；独立审查后提交正常PR并核合后CI。回滚覆盖既有出牌/药水事务中的新增分裂状态；不新增分裂或整轮敌方行动事务。注入初始化异常下的既有半插入边界须明确记录，非法定义由数据校验拒绝，不冒称完整原子性。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
分裂代码和本地回归已实现，原生 Lua 138 项入口及独立探针通过；正式提交 CI 尚待验证，不算已合并或实机通过。来源、测试与既有异常边界见技术报告。

独立评审5637220541；源、失败转通过、随机顺序及未验证边界详见技术报告。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
半血分裂的有限代码切片已实现：15项合同、138个原生Lua入口、独立128种子与回滚/五槽探针通过。PR164代码提交5ce18441的正式Quality40071605101两个作业通过；任务收口提交仍须精确CI后合并。不关闭父任务或实机关口，不声称子体初始化异常下的整轮原子性。
<!-- SECTION:FINAL_SUMMARY:END -->
