---
id: TASK-39
title: 电脑鼠标键盘游玩适配与完整流程验收（优先排期）
status: To Do
assignee: []
created_date: '2026-10-23 12:23'
labels: []
dependencies: []
references:
  - TASK-4
  - TASK-10
  - TASK-30
  - docs/design/UI_DESIGN.md
priority: high
type: feature
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户明确要求电脑鼠标键盘支持尽早排期，与手机适配并列重要。现有多设备画布预览不等于输入可用，本任务覆盖电脑实际操作与主流程。应在当前界面落地阶段优先协调排期，交互遵循已批准UI基线。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 鼠标可完成选牌、详情、选目标、出牌、取消及结束回合，拖牌与点选行为一致且不会重复执行命令
- [ ] #2 明确并展示可用键位；键盘可进行焦点导航、确认与取消，且与游戏原生输入无冲突
- [ ] #3 鼠标键盘可完成地图选路、奖励、商店、营地、事件和胜负结算及重新开始等已实现主流程
- [ ] #4 记录电脑实机操作结果和未通过项，平台限制与降级明确说明；预览及编译不冒充实机通过
<!-- AC:END -->
