---
id: TASK-15.14
title: 修正大型酸液敌人的血量和招式
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 02:52'
updated_date: '2026-10-24 03:20'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-15.14.md
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
把大型酸液敌人的血量、三个招式和出招概率做对。这项只管基础招式，半血分裂和完整实机验收另外做。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按原版核对血量65–69、吐液伤害11并塞2张污染牌、普通攻击16、虚弱2，以及出招概率和顺序。
- [ ] #2 先复现再确认修好，多只敌人、死亡边界和操作失败不会出错，也不影响中型敌人。
- [ ] #3 数据检查、相关测试和独立审查通过，复用已有的正确做法。
- [ ] #4 玩家数值和其他界面、战斗逻辑不变；分裂、完整随机规则和游戏实测的缺口仍如实保留。
<!-- AC:END -->
