---
id: TASK-34
title: 配好背景音乐和场景切歌
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 07:34'
updated_date: '2026-10-24 16:19'
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
  - docs/AUDIO_RICHNESS.md
  - docs/evidence/audio-richness-integrated-20261025.json
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24用户要求地图和每场战斗有音乐：保留已认可战斗曲，新增默认带BGM的完整构建入口，沿用原生分场景切歌；实际选曲听感和混音继续留待同候选实测。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24已从固定0b1d460完整源重建启用BGM的独立候选，40模块/UI/双true参数/图身份读回通过，0错误14警告。源推进造成首份6模块不符已保留并纠正。最终路径和hash见delivery-platform-20261024证据；未官方导入/试听，不重复同条件焦点失败。由本任务负责完整游戏启用、切歌、含声音录像及混音，交4和5收口。

最终跟进PR165：从固定3bd3afa完整源又重建开启BGM候选，40模块/1914控件/max52、双true及原生图读回全部匹配，0错误14警告；hash f699624e98f326e208d0752d6e17a6ad46a541bdd59f272310ae7a1b37df4deb，已归档根.artifacts/delivery-closeout-20261024/delivery-platform/bgm-3bd3afa/wmvm3d0jo-0/working.gil。旧0b及首份失败候选保留。新候选未官方导入/试听，后续按同版本录音和真实流程AC验收；不称RC。

2026-10-24新增npm run build:native完整音频入口：先全量源码/界面，再启用原生BGM，不再交付静音诊断副本。已实际构建audio-richness-20261024，原生图83节点/258editor，双true参数仍需独立读回复核；完整游戏地图/战斗/精英/Boss/结算曲目沿用配置。未官方导入或本轮试听，AC保持未勾。

独立冻结源1da28a8读回通过：全部模块逐byte一致、2334控件/max58、结算22节点和BGM83节点，两个nativeBgmEnabled记录均boolean true，候选hash ae1d4d9fe859652f80164d40c89bfac1dae3c016666d1ca6b19f06f766c095b4。证据docs/evidence/audio-richness-20261024.json；未官方导入/听验。

用户明确本版直接采用、不等试听，不合适后续改。补行动发声后的e974c25完整check和带BGM候选独立读回均通过；与develop最新UI集成后再重建最终副本，未冒称此前副本为当前集成版。

最终集成候选冻结源277c2a8、hash04c0e28c40bab1e67620566a5eb3ad4ac19f7f53206a0effe317f0d0351fe6ac，路径在新证据中。原生BGM图83节点、双true且全部模块独立读回匹配；保持liveWrite=0。用户取消试听前置，直接采用后再反馈；实际听验状态仍NOT_TESTED。
<!-- SECTION:NOTES:END -->
