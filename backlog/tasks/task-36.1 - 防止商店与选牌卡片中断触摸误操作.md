---
id: TASK-36.1
title: 翻页或关弹窗后，不要误买东西
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 14:26'
updated_date: '2026-10-27 15:04'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/103'
  - docs/backlog-details/TASK-36.1.md
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-36
priority: medium
type: bug
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按住商店里的卡牌后翻页、打开牌库或切换页面，再松手不应该买到当前卡牌。选牌页面也一样。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 翻页、遮挡、切页面或重开后，之前那次按住不会误购买或误选，金币和卡组不变。
- [x] #2 新的正常点击仍然可用，选牌和宝箱操作不受影响。
- [x] #3 先复现再确认修好，自动检查通过；实际手机操作没测过就写明。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26全面复核：本轮node_card_ownership真实控件6/6；既有PR103/118红绿与修复已合，最终整合PR213完整Quality成功；设备实测仍由38/42承接。

负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
本轮node_card_ownership真实控件6/6；既有PR103/118红绿与修复已合，最终整合PR213完整Quality成功；设备实测仍由38/42承接。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
