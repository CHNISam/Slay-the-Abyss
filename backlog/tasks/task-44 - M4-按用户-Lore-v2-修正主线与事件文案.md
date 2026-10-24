---
id: TASK-44
title: M4 按用户 Lore v2 修正主线与事件文案
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-24 00:50'
updated_date: '2026-10-24 00:56'
labels: []
milestone: m-5
dependencies: []
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户否决旧 compact，指定 Lore-Packet_v2.zip 为基线。保留 TASK-32 历史。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 四段主线逐字使用 v2 原文并有本地显示回归
- [x] #2 商人短反馈和两个事件正文采用包内文字，保留实际费用与结果
- [x] #3 归档 v2 来源并明确平台验收边界
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.归档 v2。2.更新表现数据和 UI 文案容量。3.回归并分层记录。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
v2 原包19项manifest逐一匹配；真实控制器专项5项通过、节点Lua29项通过；完整check运行中。未生成或实测新候选，商人形象/遭遇长文显示未完成，不计整包平台验收。
<!-- SECTION:NOTES:END -->
