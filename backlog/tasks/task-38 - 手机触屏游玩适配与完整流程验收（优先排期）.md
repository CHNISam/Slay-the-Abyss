---
id: TASK-38
title: 手机触屏游玩适配与完整流程验收（优先排期）
status: To Do
assignee: []
created_date: '2026-10-23 12:23'
labels: []
dependencies: []
references:
  - TASK-4
  - TASK-10
  - docs/design/UI_DESIGN.md
priority: high
type: feature
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户明确要求手机支持尽早排期，属于重要首发适配需求。TASK-4 仅覆盖多设备画布预览，本任务补足实际触屏操作与完整游玩。优先在当前界面落地阶段推进，不应等到最终画布预览才发现操作问题；与键鼠适配并列高优先级。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 手机触屏可完成选牌、查看详情、选择目标、出牌、取消及结束回合，不依赖鼠标悬停或键盘
- [ ] #2 触屏可完成地图选路、奖励、商店、营地、事件和胜负结算及重新开始等已实现主流程
- [ ] #3 常用手机画布下文字可读、按钮可触达，界面不出屏；拖动能力受限时保留C档点选出牌
- [ ] #4 记录手机实机操作结果、设备与未通过项；画布预览、平台编译及实机通过分别报告
<!-- AC:END -->
