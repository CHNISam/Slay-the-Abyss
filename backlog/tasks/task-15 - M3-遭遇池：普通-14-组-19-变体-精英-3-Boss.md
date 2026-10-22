---
id: TASK-15
title: M3 遭遇池：普通 14 组 / 19 变体 / 精英 3 + Boss
status: To Do
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 22:21'
due_date: '2026-10-28'
labels:
  - queued-after-M2
milestone: m-4
dependencies:
  - TASK-11
  - TASK-14
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按原版第一幕遭遇池规模配置敌人，数值走基准表。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通遭遇 14 组、敌人变体 19 种、精英 3 种可随机出现
- [ ] #2 每个敌人意图与数值按基准表配置
- [ ] #3 精英战难度明显高于普通战
- [ ] #4 分别列数据已交付、本地逐种可执行、平台抽样与难度证据，附版本SHA和未支持效果清单
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR2已有14普通遭遇/19变体/3精英/1Boss数据，PR29接入节点选取；不把数据存在当作全部敌人可战。剩余需逐种真实战斗/意图验证、随机覆盖与精英难度证据，保持To Do，M1结束前不抢跑。
<!-- SECTION:NOTES:END -->
