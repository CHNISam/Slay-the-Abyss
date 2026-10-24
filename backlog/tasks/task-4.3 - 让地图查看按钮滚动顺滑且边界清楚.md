---
id: TASK-4.3
title: 让地图查看按钮滚动顺滑且边界清楚
status: Done
assignee:
  - '@codex'
created_date: '2026-10-24 09:36'
updated_date: '2026-10-24 10:42'
labels: []
milestone: m-5
dependencies: []
documentation:
  - docs/testing/task4-3-map-navigation.md
modified_files:
  - scripts/map-ui-layout.mjs
  - src/lua/abyss_map_ui.lua
  - data/presentation/ui_theme.json
  - tests/lua/map_ui.lua
  - tests/map-ui-layout.test.mjs
parent_task_id: TASK-4
type: enhancement
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按用户要求低成本打磨M4地图导航：按钮在边界消失、点击跳跃和手势中断体验需要改善。只改地图呈现和输入，不改地图生成、节点或选路规则。实机验收继续保留。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 上下按钮固定显示，首尾禁用且不响应点击
- [x] #2 按钮与当前进度约0.2秒缓动，连续点击和手势接管行为有离线回归
- [x] #3 现有手势归属、防误入节点和地图规则回归通过
- [x] #4 记录步长评估、主题复用及尚未进行的PC和触屏实机验证
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Codex核查批准稿、接口及现有回归。2. 尝试DeepSeek Max短切片，超过时限无事件后停止；由Codex实现并先红后绿验证。3. 完整离线检查和排期门禁通过，经PR交付本地切片；物理PC/触屏和候选UI门禁保留在整体品质任务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已核对批准稿和宿主OnUpdate。DeepSeek首段Max委派5分钟以上无事件/改动后停止，最终代码与测试由Codex接管，不能计入模型产出。固定按钮/边界禁用、0.2秒ease-out、两层152px步长、连续点击及拖动接管、防旧节点点击、取消反馈均有离线回归。新增需求先红后绿；目标7JS含27地图UI/35手势通过；完整check exit0，JS962pass118skip、147Lua文件、Python16pass1skip。未构建gil/官方导入/物理PC或触屏/verify:ui；平台关口保留在TASK4/38/42。

自审补强大量同向点击后的反向用例：反向以实际显示位置单步重定向，避免仍追逐旧远目标。新断言先红后绿，修后目标7JS（含27地图UI与35手势）再次通过；最终全套复验保存offline-check-final.log。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
本地导航打磨完成：按钮固定禁用、主题两层步长、0.2秒缓动与手势中断；保持地图规则。完整离线检查通过，27项地图UI及35项手势归属复核通过；实机与整体UI门禁未验收。
<!-- SECTION:FINAL_SUMMARY:END -->
