---
id: TASK-10.1.2
title: 验证多张卡牌和长文字是否撑得住
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-22 21:55'
updated_date: '2026-10-29 05:11'
due_date: '2026-10-28'
labels:
  - art validation
  - queued-after-M3
milestone: m-5
dependencies:
  - TASK-10.1.1
references:
  - docs/art/CARD_PRODUCTION.md
  - docs/backlog-details/TASK-10.1.2.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - docs/backlog-details/MOBILE-QA-20261029-SOURCES.md
  - docs/art/UPLOAD-BUDGET-20261029.md
parent_task_id: TASK-10.1
priority: medium
type: spike
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
单张卡牌已能显示和点击，再检查1张、5张、10张同屏与长说明，确认看得清、点得动、不明显卡顿。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 已准备同一场景下的1张、5张、10张卡和长文字样本，并记录界面占用。
- [ ] #2 在游戏里测显示、点击、流畅度和反复进出，没测过的格子留空。
- [x] #3 样本和复现步骤可查，不重做战斗系统；手机、主机留待单独实测。
- [ ] #4 容量结论覆盖TASK-25实际装配资产及动态内容、选中拖放、清理和整屏成本；旧15控件探针不能批准343控件卡面或939控件肖像。
- [ ] #5 以正式144×64原生精修插画测1/5/10卡与动态数值、拖牌、切页，记录实际控件峰值、首次加载、流畅度和清理结果。
- [ ] #6 在实际安卓手机中测试完整战斗多卡、角色、敌人和场景同屏；基线与精修版同条件比较，持续试玩30分钟且没有持续增长的资源残留。
- [ ] #7 同一底图/源码先取得B0基线与B1单精绘候选的GIL、映射Lua、平台存档大小/上限及试玩上传读数和截图，区分MB/MiB与压缩口径；未知明确保留。
- [ ] #8 固定宿主增加唯一插画与固定绘图增加宿主分别测量，查重/清理并保留数据和控件两个维度；B1通过后才递进5/10及完整场景，量产批准必须同时满足确认上传上限、迭代余量和实体手机性能/清理。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
使用PR208的41档同副本样板比较纯2D、2.5D和原生3D；保持已批准视觉方向，离线/官方导入/PC/手机证据分开。只有新一轮明确键鼠窗口内才做客户端操作；正式装配与完整UI验收仍按原AC逐项完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户2026-10-25明确优先代表性同屏绘制压力与手机路线可行性，不要求精确FPS实验；切换为1435图元组合至高精度蒙版组合的快速逐档筛选，手机未实测不外推。原先基线流程错误与失焦记录保留。

2026-10-27按Owner确认的精修路线复用既有压力测试，真实成品1/5/10卡逐档，并与同游戏基线、选角及正常战斗峰值分开测；不能用旧15控件占位或PC回调间隔推断手机帧率。

2026-10-29用户明确担忧的是导入关卡后试玩上传约10MB、观察上限20MB，不是小地图图片配额。官方存档大小指上传存储预估；20MB数值/单位/压缩及映射Lua计量仍待实机。当前精绘三样本6534图形；1/5/10宿主增2703/13515/27030控件，JSON/Lua为不同表示不能相加当上传量。按UPLOAD-BUDGET-20261029补包体和运行期双门槛，不擅降认可画质或扩大批量。
<!-- SECTION:NOTES:END -->
