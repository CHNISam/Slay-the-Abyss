---
id: TASK-13.1.3
title: 核对高塔恩赐候选多样性及开局对话分支
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 17:02'
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
  - docs/reviews/M3-EVENTS-OFFLINE-COMPLETION-20261031.md
  - docs/evidence/m3-completion-20261031/
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
- [x] #1 已设计的合法候选范围、选择规则和随机结果清楚且与实际一致；不因测试配置或漏池长期固定两项。
- [x] #2 开局既定对话和选择分支的保留、缺口、实现状态清晰，玩家实际能经历批准内容；游戏规则不因视觉整改而改变。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-31 M3整批收口：核批准mini/full规则、128独立向量及真实Host首次/Boss重开/新会话/早死生命周期，对照保留分支与取消电影决定。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31只读核对：mini开局固定两项属于已批准的会话能力降级，并非本轮已证实的随机故障；完整开局对话和分支实现仍保留。当前仅源码/配置核对，不把批准降级等同于设备体验通过，不Done、不勾验收；后续与同候选会话及完整模式分别复验。

2026-10-31 PR409核正：bossCount=0时两项恩赐及合格历史时四项均已有规则；核对首次、未到Boss重开、同实例到Boss后重开，不把两项自动判为随机池Bug，不伪造跨会话历史。固定来源见docs/backlog-details/STS1-DELTA-20261031.md。

2026-10-31 M3专项：直接执行现有Fengari夹具，历史4组与候选5组（128独立oracle向量）通过；Beggar真实UI8组通过。标准Node包装受spawnSync EPERM阻塞，分列记录；固定两项/四项均已有合法规则，电影按批准决定取消。尚无本轮同候选自然/设备证据，不勾AC，不重做已合代码。技术边界见docs/reviews/M3-BACKLOG-CLOSEOUT-20261031.md。

2026-10-31 M3最终事实核对：AC1：128独立oracle、候选5组/历史4组/奖励12组，及标准neow-competition-restart通过，真实GameUI生成控件验证fresh2→到Boss同Host重开4→新Host2→早死2，provider读取次数0；固定两项是批准会话规则，不是测试漏池。AC2：真实生成intro→blessing→reward→leave回图及完整模式4项/选牌/转化/药水分支专项已通过；电影按批准取消，规则未随视觉整改改变。到Boss前缀明确受控，非自然通关。本任务收口为规则/分支诊断；官方客户端/设备体验未验，继续由父任务及候选验收承接。无额外DoD条目；计划、两AC、来源文档与验证记录已逐项核对。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已查明两项/四项恩赐为批准的会话规则，非固定池故障；128独立向量及真实Host首次/Boss重开/新Host/早死生命周期和公开对话奖励分支通过。取消电影决定保留，未改玩法。仅诊断任务完成；官方客户端/设备与父任务自然验收仍未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
