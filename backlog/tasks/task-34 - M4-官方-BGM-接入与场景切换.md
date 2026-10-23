---
id: TASK-34
title: M4 官方 BGM 接入与场景切换
status: To Do
assignee: []
created_date: '2026-10-23 07:34'
labels:
  - P1
  - bgm
milestone: m-5
dependencies:
  - TASK-17
  - TASK-29
references:
  - 'https://act.mihoyo.com/ys/ugc/tutorial/detail/mhq9b601kh9k'
  - >-
    https://github.com/8itlab/genshin-miliastra-mcp/blob/main/src/scene/media/music.json
  - docs/COMBAT_FEEDBACK.md
priority: high
type: enhancement
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用千星奇域原生背景音乐管理及music_catalog（188首为用户提供线索）。禁止自研播放器、提取或上传未经授权的原神音频。10040、10044、10071、10140、10152仅为待实机试听候选，不是已验证资产。TASK-29负责一次性战斗音效及事件队列，TASK-4负责反馈精修/多设备，本任务仅负责持续BGM及混音协调，不重复开发音效；TASK-4为协作参考，不设相互阻塞。保持M1唯一主冲刺与2026-10-30内部硬线，本次仅登记。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图探索、普通战斗、精英战、Boss战、胜利及失败结算均有经实机试听确定的原生BGM，记录最终ID与选择依据
- [ ] #2 同一候选真实播放验证循环、音量平衡、淡入淡出、场景切换和听感，保留含声音录像及试听记录；配置或编译成功不能代替实机验收
- [ ] #3 场景往返、连续进战、结算、重开及平台重新挑战均不叠播、不重复启动、不残留上一曲，有操作与结果证据
- [ ] #4 与TASK-29/TASK-4音效共同试听，关键反馈清楚，不重做音效、不改规则/RNG；平台限制、降级与验证状态分别记录
<!-- AC:END -->
