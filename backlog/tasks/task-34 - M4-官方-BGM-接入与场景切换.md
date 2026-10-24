---
id: TASK-34
title: 配好背景音乐和场景切歌
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 07:34'
updated_date: '2026-10-24 07:19'
due_date: '2026-10-28'
labels:
  - P1
  - bgm
milestone: m-5
dependencies:
  - TASK-29
references:
  - 'https://act.mihoyo.com/ys/ugc/tutorial/detail/mhq9b601kh9k'
  - >-
    https://github.com/8itlab/genshin-miliastra-mcp/blob/main/src/scene/media/music.json
  - docs/COMBAT_FEEDBACK.md
  - docs/NATIVE_BGM.md
  - docs/evidence/task34-native-bgm.json
  - docs/backlog-details/TASK-34.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/evidence/delivery-platform-20261024.json
priority: high
type: enhancement
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
为地图、战斗、Boss和胜败结算选合适的官方音乐，在游戏里确认好听、切换自然，不盖住关键音效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 各场景都选好音乐，在游戏里听过，并记下选曲。
- [ ] #2 循环、音量、淡入淡出和切歌自然，保存带声音的试玩录像。
- [ ] #3 来回切场景、连续战斗、结算和重开时，不叠播、不残留上一首。
- [ ] #4 背景音乐不盖住出牌、命中等声音；做不到的地方说明原因。
- [ ] #5 本任务负责人交付正式完整游戏的启用BGM候选，读回启用参数与原生图，完成导入、切歌和含声音录像；普通静音构建不得作为M4或RC音频验收版本。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24已从固定0b1d460完整源重建启用BGM的独立候选，40模块/UI/双true参数/图身份读回通过，0错误14警告。源推进造成首份6模块不符已保留并纠正。最终路径和hash见delivery-platform-20261024证据；未官方导入/试听，不重复同条件焦点失败。由本任务负责完整游戏启用、切歌、含声音录像及混音，交4和5收口。
<!-- SECTION:NOTES:END -->
