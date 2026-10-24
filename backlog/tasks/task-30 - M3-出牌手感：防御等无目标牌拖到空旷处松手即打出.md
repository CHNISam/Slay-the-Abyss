---
id: TASK-30
title: 拖牌到场上，松手就出牌
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 00:59'
updated_date: '2026-10-24 13:48'
due_date: '2026-10-28'
labels:
  - ui
  - combat
  - interaction
milestone: m-5
dependencies:
  - TASK-10
references:
  - docs/design/UI_DESIGN.md
  - docs/design/prototype/index.html
  - docs/backlog-details/TASK-30.md
  - docs/DELIVERY-CLOSEOUT.md
priority: high
type: enhancement
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
防御、能力和群攻等无目标牌拖到战场有效区域松手立即出牌。第一次点牌选中，再点原牌取消；备用操作是在选牌后点明确出牌区域。指定目标牌拖到合法敌人或选牌后点敌人执行。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 不需要选敌人的牌，拖到战场空地松手就出，不用第二次点击。
- [ ] #2 能看清哪里可以出牌；松在手牌区或无效位置会取消，不误点其他按钮。
- [ ] #3 需要目标的牌拖到合法敌人才能出，松在空地不能替玩家随便选敌人。
- [ ] #4 一次拖动只出一次；费用不足或当前不能出牌时，不扣费用也不丢牌。
- [ ] #5 电脑鼠标和手机触摸都测过，并保留点选出牌的备用方式。
- [ ] #6 记录游戏里的实际操作结果；做不到的说明原因，不能把点选可用当成拖牌已完成。
- [ ] #7 连续点击同一张牌两次只取消选中，不出牌；无目标牌点选后仅在明确战场出牌区确认。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复现并修正选牌、拖放区域与目标判定，保持核心规则不变。
2. 补齐双击取消、一次拖放、防重复与点选区域回归，同步规范和提示。
3. 执行离线检查，分层记录平台待验，提交PR；当前SHA CI通过后合并develop。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮修复同牌重复点击出牌、无效区域仍提交及最近敌人自动吸附；新增独立战场确认区与指针/选牌身份保护，同步规范、原型和旧测试。真实控件专项11组、原型事件5组通过，完整离线与当前SHA CI结果见本轮PR。未平台编译/导入/鼠标或手机实测，保持In Progress。免费文档核查90秒无事件后停止并由Codex接管，费用与额度节省未知。详见docs/backlog-details/TASK-30.md本轮记录。
<!-- SECTION:NOTES:END -->
