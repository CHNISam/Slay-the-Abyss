---
id: TASK-4.15
title: 修复药水说明截断与不同药水图标混用
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 23:16'
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
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：肌肉药水描述末尾在「人工」附近截断；两种不同药水在顶部槽位几乎相同图标，容易误用；开局另有HP显示成80/8的裁剪疑点。须区分素材区分度、源字符串、文本布局和实际状态，无需提前规定实现步骤。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 肌肉药水及其余长描述均完整显示，文本真实含义和使用/丢弃控件不被裁剪。
- [ ] #2 不同药水可通过正确的图形/语义可靠区分，保持原有效果和点击确认规则。
- [ ] #3 顶部生命等数值完整显示；裁剪问题与真实数值异常作出区分。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮仅针对截图HP裁剪增加map/node数值框横向余量，保留字号/autoSize/数值规则与战斗框；先核对真实GIL旗标，再验证最终布局邻距及真实宿主字符串，实机待复测不Done。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原生截图80/8裁剪继续按真实问题处理；Simulator同源码80/80完整不能冒充设备通过。已只读回读ba2c实际GIL：battle/player、map/resources/hp、node/hp均autoSize=true、font18/min14，重复启用无效。本轮仅nativeNode.topBar.hp由[-540,316,64,40]改[-536,316,80,40]，供map/node同源复用，保留原生autoSize/字号/HP规则和战斗68宽。最终布局左右与生命/金币图标留4/5间隔，真实宿主80/80及88/88字符串不变。2项定向通过；此为截图裁剪针对性余量修复，未宣称官方原生已修或药水其它项完成，AC不勾。
<!-- SECTION:NOTES:END -->
