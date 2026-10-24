---
id: TASK-15
title: 把首发敌人的数值和招式做对
status: In Progress
assignee:
  - '@Codex'
  - '@codex-enemy-parity'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-24 10:35'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-11
  - TASK-14
references:
  - docs/backlog-details/TASK-15.md
priority: high
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
检查首发普通敌人和精英的血量、攻击、出招概率和特殊能力。只算实际准备上线的敌人。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每个敌人的规则都有原版依据，差异和未知项列清楚。
- [ ] #2 血量范围、伤害、首回合和后续出招概率符合原版。
- [ ] #3 睡眠、护盾、塞牌、分裂、偷金币等选定能力真正生效，遭遇组合合法。
- [ ] #4 各个招式和特殊情况都测到，也有游戏里的实际验证记录。
- [ ] #5 保存对应版本的测试、截图或录像，不能把数据表存在当成敌人已经做好。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
M3本轮独立编组审计：MonsterHelper固定来源确认gremlin_gang应从八项有序多重池无放回抽4只，当前五只不符；medium_slimes两只中型的固定组合未找到原版依据，不能自动当Lots of Slimes映射。PR174仅处理small_slimes，不解决以上两项。具体blob/hash、Run/Nodes事务复用及回归迁移方案见docs/reviews/TASK-15-encounter-composition-audit-20261024.md，首发清单已列为必要缺口，未修改数值/池/状态，整体AC保持未勾。
<!-- SECTION:NOTES:END -->
