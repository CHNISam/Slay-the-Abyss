---
id: TASK-15
title: 完成第一幕敌人的数值与招式
status: Done
assignee:
  - '@Codex'
  - '@codex-enemy-parity'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-11
  - TASK-14
references:
  - docs/backlog-details/TASK-15.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: medium
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第一幕19种普通变体、3精英的AI、数值和特殊能力实现已交付。逐招式自然实机原AC4完整迁入TASK-47；第二至四幕新增敌人仍归TASK-61/62/64，不混入本切片完成声明。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 每个敌人的规则都有原版依据，差异和未知项列清楚。
- [x] #2 血量范围、伤害、首回合和后续出招概率符合原版。
- [x] #3 睡眠、护盾、塞牌、分裂、偷金币等选定能力真正生效，遭遇组合合法。
- [x] #4 保存对应版本的测试、截图或录像，不能把数据表存在当成敌人已经做好。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-25 正式运行时编组切片：接完整17源名绑定，保持 eager constructor 的未选成员HP/Bite消耗及选中敌人才初始化AI；HP/AI/misc按原始种子与层独立，视觉MathUtils偏移单独处理。真实Run/Nodes入口与成功提交事务一并验证，不用旧uniform或中型软泥替代缺组；其余未认证随机链明确保留，整体AC不勾。

2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
M3本轮独立编组审计：MonsterHelper固定来源确认gremlin_gang应从八项有序多重池无放回抽4只，当前五只不符；medium_slimes两只中型的固定组合未找到原版依据，不能自动当Lots of Slimes映射。PR174仅处理small_slimes，不解决以上两项。具体blob/hash、Run/Nodes事务复用及回归迁移方案见docs/reviews/TASK-15-encounter-composition-audit-20261024.md，首发清单已列为必要缺口，未修改数值/池/状态，整体AC保持未勾。

2026-10-26状态整理：旧备注中固定五小魔、两中软泥和完整队列未接属于历史。PR178/193已修编组并接17种源遭遇，PR206/213继续保留；不能按旧备注重复实现。仍待逐敌完整AI/随机边界和同候选实际验证；15.19已有3/4证据另保留。

2026-10-26全面复核：22份实际敌人fixture通过，sentry误写文件名失败保留，正确sentries另批通过；126编组向量及全部19普通/3精英修复已合。自然实机原AC4完整交47。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
22份实际敌人fixture通过，sentry误写文件名失败保留，正确sentries另批通过；126编组向量及全部19普通/3精英修复已合。自然实机原AC4完整交47。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
