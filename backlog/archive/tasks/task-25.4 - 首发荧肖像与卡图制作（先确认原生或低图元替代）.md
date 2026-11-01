---
id: TASK-25.4
title: 首发荧肖像与卡图制作（先确认原生或低图元替代）
status: To Do
assignee:
  - '@art-portrait'
created_date: '2026-10-22 16:43'
labels:
  - art
  - launch
dependencies:
  - TASK-10.1
references:
  - docs/experiments/art-portrait/README.md
parent_task_id: TASK-25
type: task
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR26两档拟合虽能导出，256图元仍模糊且27/72椭圆越出画布；首发需换适合路线，不继续堆图元。尚无获批正式荧头像，技术几何头像不能当成品。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 原生荧肖像可用性或手工低图元样张经批准并在游戏显示；直接拟合Lua的溢出风险未解决前不可批用
- [ ] #2 来源和权限明确；肖像/卡图文件与实际可玩卡牌ID映射，无素材缺口伪报
- [ ] #3 手机/主机画布、实际文字可读性和同屏控件成本有证据；独立分支/PR由主Agent审查集成
<!-- AC:END -->
