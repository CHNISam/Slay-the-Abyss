---
id: TASK-4.7
title: 显示已获得遗物和卡牌升级来源
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:39'
updated_date: '2026-10-29 01:55'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
  - docs/evidence/backlog-merge-20261029.json
parent_task_id: TASK-4
priority: medium
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手机试玩发现看不到完整持有遗物，升级来源不清；源码显示顶栏仅数量，用户该局升级来源未确认。PC实际展示和交互待核实。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 可查看完整持有遗物及其说明，卡牌升级来源可追溯。
- [ ] #2 同候选电脑和手机实测并留证。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮优先交付完整持有遗物查看，复用现有弹窗和主题分页，不丢长列表；补真实控件开关/分页/旧输入回归。该局升级来源尚未知，不伪造历史；来源追踪另保留未完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
完整持有列表入口已实现，42件含重复分页/正文/关闭/重开/旧endTurn跨弹窗拒绝两场景通过；父线程独立复验通过并经只读审查。升级来源追踪、缺定义文案和实体PC/手机仍未验，原AC不勾。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。
<!-- SECTION:NOTES:END -->
