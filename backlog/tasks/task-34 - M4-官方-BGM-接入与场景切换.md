---
id: TASK-34
title: M4 官方 BGM 接入与场景切换
status: In Progress
assignee:
  - '@codex-native-bgm'
created_date: '2026-10-23 07:34'
updated_date: '2026-10-23 08:29'
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
  - docs/NATIVE_BGM.md
  - docs/evidence/task34-native-bgm.json
priority: high
type: enhancement
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用千星奇域原生背景音乐管理及music_catalog（188首已由本轮只读目录核验）。禁止自研播放器、提取或上传未经授权的原神音频。10040、10044、10071、10140、10152及本轮补充10179仅为待实机试听候选，不是最终已验证资产。TASK-29负责一次性战斗音效及事件队列，TASK-4负责反馈精修/多设备，本任务仅负责持续BGM及混音协调，不重复开发音效；TASK-4为协作参考，不设相互阻塞。保持M1唯一主冲刺与2026-10-30内部硬线；用户2026-10-23明确要求持续并行推进，允许开展默认关闭的可审查离线切片，实机AC仍保留。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图探索、普通战斗、精英战、Boss战、胜利及失败结算均有经实机试听确定的原生BGM，记录最终ID与选择依据
- [ ] #2 同一候选真实播放验证循环、音量平衡、淡入淡出、场景切换和听感，保留含声音录像及试听记录；配置或编译成功不能代替实机验收
- [ ] #3 场景往返、连续进战、结算、重开及平台重新挑战均不叠播、不重复启动、不残留上一曲，有操作与结果证据
- [ ] #4 与TASK-29/TASK-4音效共同试听，关键反馈清楚，不重做音效、不改规则/RNG；平台限制、降级与验证状态分别记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 根据本轮持续离线推进授权，只开展可审查的原生 BGM 离线切片，保留 TASK-17/TASK-29 实机关口依赖。
2. 核对官方教程、已安装 MCP 源码的 music_catalog、原生 BGM API 与已用 Lua/节点宿主接线。
3. 仅在接口证据充分时实现配置及切换规划；未知接口留明证据与接入边界，不自研播放器或使用未授权音频。
4. 运行针对性离线验证，记录候选未试听、构建/实机分别报告；本任务实机 AC 保持未勾选。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 执行身份 codex-native-bgm；独立 worktree .worktrees/continue-native-bgm，分支 feat/continue-native-bgm，基线 52f35dd。用户本轮要求持续并行推进，扩展此前仅登记为可审查离线预备切片，不打开原神、不控制键鼠、不发布。

2026-10-23 离线切片已具备：官方背景音乐/节点说明缓存及 MCP genshin-ts@0.2.2 参数核验；music_catalog实际188条，6个ID/标题/时长逐项匹配。新增默认关闭的 nativeBgmEnabled 脚本参数，Lua宿主只在可见阶段切换后发送7种去重信号；原生图负责换曲/暂停。故障不阻断游戏，不改规则/RNG/Theme.sound。新增独立 build-native-bgm-candidate 命令，仅显式候选启用。基于085f499副本原生图编译+写副本成功：77节点/editor252、0编译警告；27Lua静态0错误/17既有警告，输入hash前后不变。npm run check全链通过：JS 587（472通过/115跳过/0失败），Lua全部通过，Python16（1跳过）；新增图3、Lua3、宿主2组，既有game_ui15组保留。详见docs/NATIVE_BGM.md、docs/evidence/task34-native-bgm.json。原神未启动，官方导入/播放/听感/无叠播/最终曲目均NOT_TESTED；四项实机AC全不勾选，任务保持In Progress。

最终接线补充：换曲后明确调用 startPausePlayerBackgroundMusic(player,true)，避免依赖换曲自动解除菜单暂停。最终图重新编译写副本通过，83节点/editor258、0编译警告；新增图回归重跑3/3通过。此前77/editor252为中间版本，最终证据与hash以docs/evidence/task34-native-bgm.json为准。
<!-- SECTION:NOTES:END -->
