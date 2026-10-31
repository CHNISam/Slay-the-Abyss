---
id: TASK-4.13
title: 让地图一眼识别当前位置已走路径和可选路线
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 10:16'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
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

发版整合：在最新develop保留PR416设计，修复返回面板八位颜色的原生RGB/独立alpha格式；按本切片明确设计更新精确视觉期望，保留全部合法路径、命中和动画裁剪断言；定向验证后交独立复审与完整CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31 独立v1-map-hud切片：保留地图/遗物栏/卡组/意图成果；撤回造成既有生命周期回归的非必要肖像预热。新增旋转ring实际外包断言已先红后绿，隐藏过渡继续收敛并重新显示。真实拖牌8组、动态敌人目标归属/多实例/1至5敌人意图几何通过；地图及双幕定向7项、12遗物条及地图窄验8项通过。PC/手机原生可辨识与官方导入仍未验证，AC不勾选。

2026-10-31发版集成：从96411b6重建PR416，保留原地图/顶栏设计。原生颜色合同实际抓到previewBack/combatRewards的8位RGBA；改复用plate转换为6位RGB与独立alpha，并新增两层精确颜色、透明度、几何与层序断言。地图已走节点改金色路径、仅当前留光圈等设计对应的旧视觉期望已同步；合法路线、控制器、滚动裁剪、满尺寸hit与药水生命周期断言保留。首批7文件18/18及Backlog/指引通过；正式CI、官方导入及PC/手机验收独立待验，不勾AC。

补充最终本地证据：两批14文件33项Node测试全通过；map_ui原27项通过；增强独立颜色/near-far透明度断言后map-node再次通过。架构316模块1811边、工程质量4959项、JS语法与license inventory通过（仅按既有冻结名单物化6张LFS图，5983528逻辑字节）。工程静态检查实际发现并移除本切片未使用palette；无放宽门槛。完整托管CI与平台验收仍未认证。
<!-- SECTION:NOTES:END -->
