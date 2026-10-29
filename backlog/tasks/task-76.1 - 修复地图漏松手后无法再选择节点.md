---
id: TASK-76.1
title: 修复手机地图漏松手后无法选节点
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
parent_task_id: TASK-76
priority: medium
type: bug
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手机实玩出现地图无法点击；离线对照复现漏释放后的锁定，尚未确认用户那次事件链。PC鼠标是否出现同问题待验证，不预设跨端。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图漏松手或触摸中断后可再次选择节点且不误触。
- [ ] #2 保留回归与同候选手机实测证据。
- [ ] #3 手机触屏和PC鼠标分别验证中断释放后的恢复，记录设备、候选和结果。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先红例复现地图漏Up后新节点永远被拒；恢复同指针新手势且保留旧Up/跨节点/多指隔离；相关输入回归后写入统一测试包，实体手机由用户验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
同一非nil touchId的背景地图漏Up→新节点完整tap恢复已实现；延迟背景Up不能提交。原地图35组及新增回归通过。node自身漏Up/异touch恢复未证，实体手机仍待验，不关闭整项。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。
<!-- SECTION:NOTES:END -->
