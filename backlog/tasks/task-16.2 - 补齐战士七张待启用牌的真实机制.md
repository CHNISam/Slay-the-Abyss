---
id: TASK-16.2
title: 补齐战士七张待启用牌的真实机制
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 06:52'
updated_date: '2026-10-27 04:15'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - data/SOURCES.md
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-16
priority: medium
type: feature
ordinal: 100000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前战士仍有七张已有定义却无法使用的牌，力量成长、消耗、格挡和自伤回血构筑因此不完整。先在明确的实验入口实现并验证，不把尚无原生选牌界面的卡直接放入默认发布池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 交锋、坚毅、战吼、金属化、恶魔形态、旋风斩和死亡收割基本及升级规则逐项核实并执行。
- [x] #2 随机耗牌与选牌置顶保持不同的单候选随机数语义，使用牌不提前进入选择池。
- [x] #3 X费按使用快照执行普通伤害矩阵，吸血按实际损失生命并延后治疗，不能提前救活应被反伤击杀的玩家。
- [x] #4 默认发布池保持原有门禁；化学物X、死灵书和未完成消耗钩子明确列为缺口，不冒充完整原版验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
已核固定来源七牌及选择/X费/吸血时点；独立实验数据与手牌选择模块由subagent实施，主线程接新队列及普通伤害快照。新机制仅实验入口启用，默认发布数据与30牌门禁保持；先定向回归再合并下一阶段验证，不提交推送。

2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26全面复核：七张机制早已纳入PR196原生75；本轮warrior_choices13组和完整75/边界回归通过；默认能力门禁由已验证75整体启用取代旧blocked，化学物X等未完交互明确留47/59。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
七张机制早已纳入PR196原生75；本轮warrior_choices13组和完整75/边界回归通过；默认能力门禁由已验证75整体启用取代旧blocked，化学物X等未完交互明确留47/59。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
