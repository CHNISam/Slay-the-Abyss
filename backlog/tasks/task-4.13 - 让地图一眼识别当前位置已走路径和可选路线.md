---
id: TASK-4.13
title: 让地图一眼识别当前位置已走路径和可选路线
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-11-02 02:20'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - backlog/tasks/task-95 - 对照验证美术、交互与动效设计工具.md
parent_task_id: TASK-4
priority: medium
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner强调地图是**整体交互体验**问题：当前节点和连线灰暗、星星和金色路线不足以建立位置感；已走节点、当前位置、下一步可选节点难以区分。不得当作单一颜色/对比度调整，也不改变地图生成和规则。复用已 Done 的TASK-4.3滚动成果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图静态可见时能清楚回答「我在哪、走过哪里、下一步能去哪」。
- [ ] #2 不同节点/线路状态、对比度和交互反馈整体协调，PC/手机实际屏幕上可辨。
- [ ] #3 不回退既有地图滚动、点击输入以及合法路径判定。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用PR401原四提交，按真实动画绘制外包修复地图裁剪；验证路径、点击和双幕地图，不扩大美术范围。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31 独立v1-map-hud切片：保留地图/遗物栏/卡组/意图成果；撤回造成既有生命周期回归的非必要肖像预热。新增旋转ring实际外包断言已先红后绿，隐藏过渡继续收敛并重新显示。真实拖牌8组、动态敌人目标归属/多实例/1至5敌人意图几何通过；地图及双幕定向7项、12遗物条及地图窄验8项通过。PC/手机原生可辨识与官方导入仍未验证，AC不勾选。

2026-11-02最新排期：优先M4非美术、非交互设计工程。地图整体视觉交互新方案先取TASK-95对应实验结论；滚动、裁剪、点击命中与合法路径明确缺陷继续修复，复用TASK-4.3，不因实验停止稳定路径验证。 仅对应新增正式设计切片以实验结论为前置；未来纯设计优化子任务显式依赖TASK-95并引用适用Go结论。本混合任务不新增整任务硬依赖，原状态与AC保留。
<!-- SECTION:NOTES:END -->
