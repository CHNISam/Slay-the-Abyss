---
id: TASK-39
title: 检查验收截图是不是真图片
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 12:55'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-29'
labels: []
milestone: m-6
dependencies: []
references:
  - scripts/verify-ui-acceptance.mjs
  - docs/design/ui-acceptance.json
  - docs/backlog-details/TASK-39.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: medium
type: bug
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
避免把空文件、文件夹或不存在的路径误当成游戏截图，导致没验过也显示通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 只有实际存在、非空的图片文件才能使用；空文件、文件夹和坏路径要报错。
- [x] #2 正常截图仍能使用，原来的检查项保留；有错误时不能显示通过。
- [x] #3 用真实文件测试这些错误情况，检查通过；不改变其他任务的完成状态。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26全面复核：PR111实现已合；锁定依赖从本机缓存补齐后ui-acceptance真实PNG正负例通过，最终PR213全绿；不认证游戏画面或修改其他任务。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR111实现已合；锁定依赖从本机缓存补齐后ui-acceptance真实PNG正负例通过，最终PR213全绿；不认证游戏画面或修改其他任务。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
