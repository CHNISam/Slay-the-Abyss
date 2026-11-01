---
id: TASK-4.21
title: 定位玩家反馈的手机卡顿与加载慢
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-31 23:38'
updated_date: '2026-11-01 00:16'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/TASK-4.21.md
  - docs/evidence/mobile-readability-20261101/
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 136000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
同一批玩家反馈还包含很卡，具体阶段未知；加载慢和低配置均为待验证猜测。独立排查逐帧重复写入、切页重建与加载路径，优先保留可重复证据，不更换已延期优化的背景。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 分别记录启动加载、静止帧、战斗与切页路径的已证实事实和未知项，不将mock耗时或配置猜测当真机根因。
- [x] #2 对已证实的冗余原生写入作最小修复，保持滚动、状态更新、生命周期与失败恢复正确，并有前后调用计数回归。
- [ ] #3 同候选手机记录设备、启动和交互耗时，区分冷载、持续卡顿及累积实例；未实测不宣称手机性能已修好。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 独立计数地图和战斗静止帧及覆盖页切换。2. 有证据后只消除同值重复原生写入，不动背景算法或提高门槛。3. 验证状态变化、回页和新对象仍更新，独立审查并与字体修复一起交付。4. 实机性能结论保持待验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01 已证实并修复地图重复尺寸与意图图文写入；db4014c5独审PASS并整合04e3a75e。300次离线更新地图15000→1200次尺寸提交，意图文字/图片300→0次重复提交；呼吸/滚动/粒子保持原路径。跨地图与控制器共享native控件、部分成功后返回false/throw均有RED→GREEN；两次Important拒绝及修正证据保留。Root实际两raw场景共13项与独审通过；没有手机FPS/P95/冷载结论，actor覆盖页重建仅调查、本批未动，实际卡顿原因与AC3保持未验。
<!-- SECTION:NOTES:END -->
