---
id: TASK-13.1.3
title: 核对高塔恩赐候选多样性及开局对话分支
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 15:15'
labels:
  - playtest-20261030
  - p1
  - gpt
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - docs/reviews/M3-BACKLOG-CLOSEOUT-20261031.md
parent_task_id: TASK-13.1
priority: medium
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner多次重开均见同一两项恩赐（前三场敌人生命为1、增加最大生命8），疑似固定池或选择机制有误；此前设计过开局人物交谈与少量分支，目前体验几乎只有二选一。先与既定原版和本作事件配置对照，避免仅凭两项相同就断定随机代码错误。GROK另负责界面。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 已设计的合法候选范围、选择规则和随机结果清楚且与实际一致；不因测试配置或漏池长期固定两项。
- [ ] #2 开局既定对话和选择分支的保留、缺口、实现状态清晰，玩家实际能经历批准内容；游戏规则不因视觉整改而改变。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31只读核对：mini开局固定两项属于已批准的会话能力降级，并非本轮已证实的随机故障；完整开局对话和分支实现仍保留。当前仅源码/配置核对，不把批准降级等同于设备体验通过，不Done、不勾验收；后续与同候选会话及完整模式分别复验。

2026-10-31 PR409核正：bossCount=0时两项恩赐及合格历史时四项均已有规则；核对首次、未到Boss重开、同实例到Boss后重开，不把两项自动判为随机池Bug，不伪造跨会话历史。固定来源见docs/backlog-details/STS1-DELTA-20261031.md。

2026-10-31 M3专项：直接执行现有Fengari夹具，历史4组与候选5组（128独立oracle向量）通过；Beggar真实UI8组通过。标准Node包装受spawnSync EPERM阻塞，分列记录；固定两项/四项均已有合法规则，电影按批准决定取消。尚无本轮同候选自然/设备证据，不勾AC，不重做已合代码。技术边界见docs/reviews/M3-BACKLOG-CLOSEOUT-20261031.md。
<!-- SECTION:NOTES:END -->
