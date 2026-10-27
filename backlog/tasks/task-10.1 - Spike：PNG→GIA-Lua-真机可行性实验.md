---
id: TASK-10.1
title: 先验证卡图能不能放进游戏
status: Done
assignee:
  - '@codex'
created_date: '2026-10-22 15:57'
updated_date: '2026-10-27 04:23'
due_date: '2026-10-28'
labels:
  - technical-spike
  - queued-after-M3
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/TASK-10.1.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/art/CARD_PRODUCTION.md
  - docs/art/evidence/2026-10-23.json
parent_task_id: TASK-10
priority: medium
type: spike
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用一张小样验证图片能否在游戏里正常显示和点击，再决定正式卡图怎么制作。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 记录样图、导入方法和尺寸、透明度、容量限制；失败也能复现。
- [x] #2 分别记清文件做出、导入、游戏显示和点击的结果；不改正式存档，不自动发布。
- [x] #3 给出可用规格、手机等设备的风险；做不到时说明替代办法。
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
单卡可行性探针已由10.1.1及CARD_PRODUCTION.md/2026-10-23结构化证据完成：180×240画布、148×208卡框、11图形+4原生文字、标题40高兼容、官方副本读回、用户截图显示及点击通过；33.3ms均值/34.0ms P95仅该电脑单卡dt。手机/多卡/长文/完整资产继续由10.1.2、25、38、42承担，不因父探针重复挂To Do。
<!-- SECTION:FINAL_SUMMARY:END -->
