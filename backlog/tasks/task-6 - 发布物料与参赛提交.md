---
id: TASK-6
title: M5 正式投稿（人执行，Agent 出操作说明）
status: To Do
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 22:25'
due_date: '2026-10-30'
labels: []
milestone: m-0
dependencies:
  - TASK-19
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
由人在千星沙箱上传界面勾选「千星之约·奇域创作大赛」并发布。Agent 只提供逐步操作说明与检查表，不得虚报投稿成功。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Agent 输出逐步发布与赛事报名操作说明 + 发布前检查表
- [ ] #2 人完成发布与投稿，截图留存投稿成功凭证
- [ ] #3 最终确认赛事、作品GUID、版本候选与提交限制；保留发布成功和赛事回查凭证，非仅上传成功
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
修复依赖方向：TASK-20应在真实发布之后记录版本；本任务不再等待TASK-20。原投稿后规则研究迁TASK-21（非M5阻塞），发布前关键限制仍在本任务与TASK-19。

发布操作说明与检查表由PR8合入docs/PUBLISHING.md，AC1已有可复核交付；正式投稿及最终确认AC仍未完成。
<!-- SECTION:NOTES:END -->
