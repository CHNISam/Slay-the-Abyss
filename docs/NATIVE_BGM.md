# 原生 BGM 候选接入（TASK-34）

此切片已具备离线原生接线；**战斗曲10044已在2026-10-23独立音频存档由用户试听并暂定保留，其余曲目未试听，TASK-34四项完整游戏实机AC仍保留**。本轮记录见[SFX_SELECTION](SFX_SELECTION.md)。没有提取、上传或附带音频文件，没有自研播放器。持续BGM由平台按玩家管理，一次性音效仍由TASK-29负责。

## 接口依据

- [官方背景音乐指南](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhq9b601kh9k)描述编辑器音乐配置及节点图控制；[官方服务器节点说明](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhw66orrrfkm)列出设置、音量和启动/暂停节点。网页仅返回页面壳，本轮同时核对安装工具携带的这两页官方离线缓存。
- MCP `search_node_docs` 实际返回 `genshin-ts@0.2.2` 的 `modifyPlayerBackgroundMusic(PlayerEntity, IntValue, FloatValue, FloatValue, IntValue, BoolValue, FloatValue, FloatValue, BoolValue)` 与 `startPausePlayerBackgroundMusic(PlayerEntity, BoolValue)`，不是猜测 Lua 播放接口。
- 本机工具提交 `7091060417fe9bd1231e812db4f798c97a5c63d1`；`music_catalog` 实际返回 188 条。目录记录日期为 2026-10-11，文件 SHA256 `29fe676b0886548fee65b01a263560f3a8228cf4f43898e8f6b6ae7bceb83150`。目录可用不代表本账号已试听或获选为最终曲目。

## 候选与切换

配置唯一来源是 `data/presentation/native_bgm.json`。下面是用于首次试听的占位选择；只根据目录分类/标题初选，没有听感判断。音量 45/40 是待调起点，不是已混音值。

| 画面/阶段 | 原生 ID / 目录标题 | 长度 | 循环 / 音量 |
|---|---|---|---|
| 地图、商店、营地、事件、宝箱、普通战后奖励 | 10040 谨慎的探索 | 57 s | 是 / 45 |
| 普通战斗，含问号战斗 | 10044 战斗的秘仪 | 261 s | 是 / 45 |
| 精英战 | 10071 难逃之阵 | 256 s | 是 / 45 |
| Boss 战 | 10140 无尽的挑战 | 323 s | 是 / 45 |
| 第一幕胜利结果 | 10152 欢笑的凯旋 | 111 s | 否 / 40 |
| 失败结果 | 10179 愁绪谧息 | 129 s | 否 / 40 |
| 初始菜单、提交平台结算后 | 暂停原生 BGM | — | — |

失败曲 10179 是本轮从同一目录补充的未试听候选。完整片段从 0 到目录长度、速度 1、循环间隔 0，统一允许原生淡入淡出。结果曲播完保持结束，不用定时器重新拉起。淡出时长和不同曲间的过渡由平台控制，没有假设可调秒数或叠播行为。

Lua 宿主从可见界面和已结算状态选场景，敌方最后受击/死亡/胜负横幅仍在回放时保持当前战斗曲。开关牌库、刷新数字不换曲；本局重开回到地图曲；平台重新挑战重新创建宿主和图变量。每次原生换曲后明确调用恢复播放，避免依赖换曲是否自动解除菜单暂停。Lua 与原生图各做一次去重，故障隔离在音频回调内，不改规则、RNG、输入或结算。去重单元测试不能证明平台无叠播，仍需实际录音。

## 构建输入/输出契约

2026-10-24起，完整音频交付优先使用 `npm run build:native -- <底图.gil> <新输出目录>`：先重建所有Lua和界面，再为完整副本开启原生BGM，最终清单在输出目录的 `audio/candidate.json`。低层静音构建命令继续用于隔离诊断；它不能作为本轮用户要求的带音乐交付。场景配置仍来自 `data/presentation/native_bgm.json`，不会把未试听曲目写成已精选定稿。

常规 `build-native-candidate.mjs` 保持关闭：`abyss_ui` 的脚本变量 `nativeBgmEnabled` 缺省/false 时不发送 BGM 信号。只有专用副本显式设置 boolean true 才开启。

```powershell
node scripts/build-native-bgm-candidate.mjs <完整游戏副本.gil> .artifacts/native-bgm-candidate
```

输入必须为与当前代码兼容、已包含完整游戏控件和结算图的**单人**候选；不要传官方正式存档、重复叠加 BGM 候选或陈旧规则底图。先生成最新全量离线副本，再叠此切片。命令强制 `MILIASTRA_ALLOW_LIVE_WRITE=0`，不启动游戏、不导入或试玩。它只更新 `abyss_bgm`、`abyss_game_ui`、`abyss_ui` 三个脚本，注册七个无参数信号 `ABYSS_BGM_MAP/BATTLE/ELITE/BOSS/VICTORY/DEFEAT/STOP`，创建 stage 上的原生服务端 `ABYSS_BGM` 图，编译并静态检查，再输出 `candidate.json`（输入/输出 hash、编译和静态检查、未验状态）与 `bgm.ts`。其他脚本保留输入内容，因此不能把叠加构建当成全量更新。

统一构建也可导入 `nativeBgmSignals` / `nativeBgmGraphSource`：用 `scene_add_signal` 注册信号；以 `scene_add_graph` 返回的真实 id/name 生成图；写入所有运行脚本时为 `abyss_ui` 增加 `{name:'nativeBgmEnabled',type:'boolean',value:true}`；调用 `write_graphs`。图只支持目前单人关卡，不能直接扩展成多人独立场景状态。

## 本轮离线证据

详见 `docs/evidence/task34-native-bgm.json`。基于已有 `085f499` 离线副本叠加本切片，输入 hash 前后一致；最终 BGM 图编译/副本写入成功，83 节点 / editor 258、0 编译警告。27 个 Lua 静态检查 0 错误 / 17 既有自定义方法与未挂载 reducer 警告。`npm run check` 全链通过；最后补充明确恢复播放后，重跑图回归 3/3 并重新编译最终副本通过。没有操作原神或正式存档；没有官方导入、实际出声、循环、混音或无叠播证据。

## 后续实机记录

在同一最新候选、同一 SHA 上录制含声音的录像，订阅 `ABYSS_BGM` 图与客户端日志，对照 `ABYSS_BGM_REQUEST` / `ABYSS_BGM_APPLIED`；日志只证明请求/节点触发，不证明听感。逐项记录每条操作、时间、最终 ID、选择理由、录像路径和结果：

1. 地图→普通战→奖励→地图、精英战、Boss 战→胜利、失败，各试听一次；至少让地图曲完整跨过 57 秒循环点，确认片段边界与过渡。
2. 相同画面连续刷新/开关牌库、连续进战、商店/营地往返，确认未重启或叠播；结果页停留超过完整曲长。
3. 失败/胜利后重新启程，结果提交平台结算，再按平台重新挑战，确认旧曲不残留、开局状态重置。
4. 与 TASK-29 音效同时试听攻击、格挡、多段、死亡和回合提示；调整候选音量，并按实际能力记录淡入淡出限制或降级。最后补手机/主机听感与音量。没有录音前不选择最终曲目、不勾实机 AC。
