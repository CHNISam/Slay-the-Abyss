---
id: TASK-30
title: M3 出牌手感：防御等无目标牌拖到空旷处松手即打出
status: To Do
assignee: []
created_date: '2026-10-23 00:59'
due_date: '2026-10-28'
labels:
  - ui
  - combat
  - interaction
milestone: m-4
dependencies:
  - TASK-10
references:
  - docs/design/UI_DESIGN.md
  - docs/design/prototype/index.html
priority: high
type: enhancement
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户反馈：目前防御牌需要点两次才能打出，手感割裂，不符合期望的《杀戮尖塔》式操作。TASK-10 仅在评论提及拖牌，缺少独立验收。主要路径应为抓起手牌、拖离手牌区至战场空旷出牌区、松手立即出牌，无需再次点击卡牌、玩家或确认按钮。按实际目标规则覆盖无目标牌，不按防御牌名称硬编码；点选仅作备用。遵循批准视觉基线，平台限制须实际探测并记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 防御及其他无需指定敌人的可用牌，按住拖至战场空旷出牌区松手即打出，无需第二次点击或确认，不要求落在玩家或敌人身上。
- [ ] #2 有效出牌区有清晰反馈；在手牌区或无效区域松手取消并回原位，不误触结束回合、药水等控件。
- [ ] #3 指定敌人的牌拖到合法敌人松手打出；多敌人时松在空地不得随机选目标。
- [ ] #4 一次拖放最多提交一次；能量不足、不可用牌、敌方回合或结算期间不出牌、不扣能量、不丢牌。
- [ ] #5 保留点选备用路径；桌面鼠标与手机触摸分别验证拖起、空地松手出牌、取消和连续出牌，说明文案与操作一致。
- [ ] #6 分别报告离线检查、平台编译、副本导入、游戏内操作验证；平台限制导致未实现时记录证据与降级缺口，不以原型通过或点选可用替代验收。
<!-- AC:END -->
